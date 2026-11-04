defmodule AshAuthenticationDevUsers do
  @moduledoc """
  Configured development users for AshAuthentication resources.
  """

  alias AshAuthentication.Info

  def enabled? do
    Application.get_env(:ash_authentication_dev_users, :enabled, false)
  end

  def list(resource) do
    resource
    |> Info.strategy!(:dev_users)
    |> Map.fetch!(:users)
  end
end
