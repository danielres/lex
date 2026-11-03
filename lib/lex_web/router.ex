defmodule LexWeb.Router do
  use LexWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug LexWeb.Collaborator
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

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {LexWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {LexWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {LexWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", LexWeb do
    pipe_through :browser

    live_session :app,
      on_mount: LexWeb.Collaborator,
      session: {LexWeb.Collaborator, :live_session, []} do
      live "/", HomeLive

      scope "/:space_slug" do
        live "/", SpaceLive
        live "/wiki", WikiLive
        live "/wiki/:page_slug", PageLive, :show
        live "/wiki/:page_slug/revisions", PageLive, :revisions
        live "/wiki/:page_slug/revisions/:revision_id", PageLive, :revisions
      end
    end

    post "", AshTypescriptRpcController, :run
    post "", AshTypescriptRpcController, :validate
    get "/ash-typescript", PageController, :index
    auth_routes AuthController, Lex.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      overrides: [LexWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{LexWeb.LiveUserAuth, :live_no_user}],
                  overrides: [LexWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [LexWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the confirmation strategy
    confirm_route Lex.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [LexWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Lex.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [LexWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
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
