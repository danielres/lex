defimpl AshAuthentication.Strategy, for: AshAuthenticationDevUsers.Strategy do
  alias Ash.{Changeset, PlugHelpers}
  alias AshAuthentication.Errors.AuthenticationFailed

  import AshAuthentication.Plug.Helpers, only: [store_authentication_result: 2]

  def name(strategy), do: strategy.name

  def phases(_strategy), do: [:sign_in]

  def actions(_strategy), do: [:sign_in]

  def routes(_strategy) do
    [{"/sign-in", :sign_in}]
  end

  def method_for_phase(_strategy, :sign_in), do: :post

  def plug(strategy, :sign_in, conn) do
    params = Map.take(conn.params, ["user"])

    options =
      [
        actor: PlugHelpers.get_actor(conn),
        tenant: PlugHelpers.get_tenant(conn),
        context: PlugHelpers.get_context(conn)
      ]
      |> Enum.reject(&is_nil(elem(&1, 1)))

    result = action(strategy, :sign_in, params, options)
    store_authentication_result(conn, result)
  end

  def action(strategy, :sign_in, params, options) do
    strategy.resource
    |> Changeset.new()
    |> Changeset.set_context(%{private: %{ash_authentication?: true}})
    |> Changeset.for_create(strategy.sign_in_action_name, params, options)
    |> Ash.create()
    |> case do
      {:ok, record} ->
        {:ok, record}

      {:error, error} ->
        {:error, AuthenticationFailed.exception(strategy: strategy, caused_by: error)}
    end
  end

  def tokens_required?(_strategy), do: true
end
