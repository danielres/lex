defmodule AshAuthenticationDevelopment do
  @moduledoc """
  Development-only authentication for AshAuthentication resources.
  """

  alias AshAuthentication.Info

  def enabled? do
    Application.get_env(:ash_authentication_development, :enabled, false)
  end

  def users(resource, strategy_name \\ :development) do
    resource
    |> Info.strategy!(strategy_name)
    |> Map.fetch!(:users)
  end
end
