defmodule AshAuthenticationDevUsers.Strategy.Transformer do
  @moduledoc false

  alias Ash.Resource
  alias AshAuthenticationDevUsers.Strategy.Change
  alias Spark.Dsl.Transformer

  import AshAuthentication.Strategy.Custom.Helpers

  def transform(strategy, dsl_state) do
    sign_in_action_name = :"sign_in_with_#{strategy.name}"
    strategy = %{strategy | sign_in_action_name: sign_in_action_name}

    with {:ok, identity} <- fetch_identity(dsl_state, strategy),
         {:ok, attributes} <- validate_users(dsl_state, strategy, identity),
         {:ok, action} <- build_action(strategy, identity, attributes) do
      dsl_state = Transformer.add_entity(dsl_state, [:actions], action)
      dsl_state = register_strategy_actions(strategy.sign_in_action_name, dsl_state, strategy)
      dsl_state = put_strategy(dsl_state, strategy)

      {:ok, dsl_state}
    end
  end

  defp fetch_identity(dsl_state, strategy) do
    case Enum.find(Resource.Info.identities(dsl_state), &(&1.name == strategy.identity)) do
      nil ->
        {:error, dsl_error(strategy, "identity #{inspect(strategy.identity)} does not exist")}

      identity ->
        {:ok, identity}
    end
  end

  defp validate_users(dsl_state, strategy, identity) do
    with :ok <- validate_non_empty_users(strategy),
         {:ok, attributes} <- common_attributes(strategy),
         :ok <- validate_attributes_exist(dsl_state, strategy, attributes),
         :ok <- validate_identity_attributes(strategy, identity, attributes) do
      {:ok, attributes}
    end
  end

  defp validate_non_empty_users(%{users: [_user | _users]}), do: :ok

  defp validate_non_empty_users(strategy) do
    {:error, dsl_error(strategy, "users must contain at least one configured user")}
  end

  defp common_attributes(strategy) do
    strategy.users
    |> Enum.reduce_while(nil, fn
      {key, attributes}, nil when is_atom(key) and is_map(attributes) ->
        {:cont, attributes |> Map.keys() |> Enum.sort()}

      {key, attributes}, expected when is_atom(key) and is_map(attributes) ->
        attributes = attributes |> Map.keys() |> Enum.sort()

        if attributes == expected do
          {:cont, expected}
        else
          {:halt,
           {:error, dsl_error(strategy, "all configured users must provide the same attributes")}}
        end

      _user, _expected ->
        {:halt, {:error, dsl_error(strategy, "users must map atom keys to attribute maps")}}
    end)
    |> case do
      {:error, error} -> {:error, error}
      attributes -> {:ok, attributes}
    end
  end

  defp validate_attributes_exist(dsl_state, strategy, attributes) do
    missing = Enum.reject(attributes, &Resource.Info.attribute(dsl_state, &1))

    if missing == [] do
      :ok
    else
      {:error,
       dsl_error(strategy, "configured user attributes do not exist: #{inspect(missing)}")}
    end
  end

  defp validate_identity_attributes(strategy, identity, attributes) do
    missing = identity.keys -- attributes

    if missing == [] do
      :ok
    else
      {:error,
       dsl_error(
         strategy,
         "configured users must provide identity attributes: #{inspect(missing)}"
       )}
    end
  end

  defp build_action(strategy, identity, attributes) do
    arguments = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :create], :argument,
        name: :user,
        type: :string,
        allow_nil?: false
      )
    ]

    changes = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :create], :change, change: Change)
    ]

    Transformer.build_entity(Resource.Dsl, [:actions], :create,
      name: strategy.sign_in_action_name,
      arguments: arguments,
      changes: changes,
      upsert?: true,
      upsert_identity: identity.name,
      upsert_fields: attributes -- identity.keys
    )
  end

  defp dsl_error(strategy, message) do
    Spark.Error.DslError.exception(
      module: strategy.resource,
      path: [:authentication, :strategies, strategy.name],
      message: message
    )
  end
end
