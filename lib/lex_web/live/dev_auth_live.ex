defmodule LexWeb.DevAuthLive do
  use LexWeb, :live_view

  alias Lex.Accounts.User
  alias LexWeb.Components.Avatar

  @impl true
  def mount(_params, _session, socket) do
    users = User |> AshAuthenticationDevUsers.list()
    {:ok, assign(socket, :users, users)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-svh flex items-center justify-center p-4">
      <div class="w-full max-w-sm space-y-4">
        <h1 class="text-xl font-semibold">Choose a user</h1>

        <div class="grid gap-2">
          <.form :for={{key, user} <- @users} for={%{}} action="/dev/auth/sign-in" method="post">
            <input name="user" type="hidden" value={key} />
            <button
              class="btn btn-block btn-ghost justify-start"
              data-testid="dev-user"
              data-user={key}
              type="submit"
            >
              <Avatar.render user={user} />
              {user.display_name}
            </button>
          </.form>
        </div>
      </div>
    </main>
    """
  end
end
