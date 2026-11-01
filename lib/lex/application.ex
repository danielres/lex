defmodule Lex.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Group, name: :lex},
      LexWeb.Telemetry,
      Lex.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:lex, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:lex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Lex.PubSub},
      {Registry, keys: :unique, name: Lex.Collaboration.Registry},
      {DynamicSupervisor, name: Lex.Collaboration.DocumentSupervisor, strategy: :one_for_one},
      # Start to serve requests, typically the last entry
      LexWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LexWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
