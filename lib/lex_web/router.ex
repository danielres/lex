defmodule LexWeb.Router do
  use LexWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", LexWeb do
    pipe_through :browser

    if Application.compile_env(:ash_authentication_dev_users, :enabled, false) do
      live "/dev/auth/sign-in", DevAuthLive
      auth_routes DevAuthController, Lex.Accounts.User, path: "/dev/auth"
    end

    post "", AshTypescriptRpcController, :run
    post "", AshTypescriptRpcController, :validate
    get "/ash-typescript", PageController, :index

    sign_out_route AuthController, "/sign-out",
      overrides: [LexWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    ash_authentication_live_session :app,
      on_mount: [{LexWeb.LiveUserAuth, :live_user_required}] do
      live "/", HomeLive

      scope "/:space_slug" do
        live "/", SpaceLive
        live "/wiki", WikiLive
        live "/wiki/:page_slug", PageLive, :show
        live "/wiki/:page_slug/revisions", PageLive, :revisions
        live "/wiki/:page_slug/revisions/:revision_id", PageLive, :revisions
      end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LexWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:lex, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
