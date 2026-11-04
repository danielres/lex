defmodule AshAuthenticationDevelopment.Strategy.Change do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.{Changeset, Resource}
  alias AshAuthentication.{Errors.AuthenticationFailed, Info, Jwt}
  alias AshAuthenticationDevelopment, as: Development

  @impl true
  def change(changeset, opts, context) do
    with true <- Development.enabled?(),
         {:ok, strategy} <- Info.find_strategy(changeset, context, opts),
         user_key when is_binary(user_key) <- Changeset.get_argument(changeset, :user),
         {_key, attributes} <- find_user(strategy.users, user_key) do
      changeset
      |> change_attributes(attributes)
      |> Changeset.after_transaction(&put_token(&1, &2, context))
    else
      _reason -> Changeset.add_error(changeset, AuthenticationFailed.exception())
    end
  end

  defp find_user(users, user_key) do
    Enum.find(users, fn {key, _attributes} -> Atom.to_string(key) == user_key end)
  end

  defp change_attributes(changeset, attributes) do
    Enum.reduce(attributes, changeset, fn {attribute, value}, changeset ->
      Changeset.force_change_attribute(changeset, attribute, value)
    end)
  end

  defp put_token(_changeset, {:ok, record}, context) do
    with {:ok, token, _claims} <- Jwt.token_for_user(record, %{}, Ash.Context.to_opts(context)) do
      {:ok, Resource.put_metadata(record, :token, token)}
    end
  end

  defp put_token(_changeset, {:error, error}, _context), do: {:error, error}
end
