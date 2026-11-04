# AshAuthenticationDevUsers

An AshAuthentication strategy for choosing from a configured set of users during development. Selecting a user lazily creates or updates the record through an identity and returns a normal AshAuthentication session token.

## Setup

Add the package and enable it only in development and test:

```elixir
{:ash_authentication_dev_users, path: "packages/ash_authentication_dev_users"}
```

```elixir
config :ash_authentication_dev_users, enabled: true
```

Configure the user resource:

```elixir
use Ash.Resource,
  extensions: [AshAuthentication, AshAuthenticationDevUsers.Strategy]

authentication do
  strategies do
    dev_users do
      identity :unique_display_name

      users(
        tom: %{display_name: "Tom", hue: 25},
        sandra: %{display_name: "Sandra", hue: 115}
      )
    end
  end
end
```

Mount the strategy routes under a development-only prefix:

```elixir
live "/dev/auth/sign-in", DevAuthLive
auth_routes DevAuthController, MyApp.Accounts.User, path: "/dev/auth"
```

This exposes `POST /dev/auth/sign-in`, accepting the configured key as the `user` parameter. Applications own the picker UI and can read its entries with:

```elixir
MyApp.Accounts.User |> AshAuthenticationDevUsers.list()
```

A minimal picker LiveView can render regular forms so authentication still runs through the HTTP route and stores the session cookie. With Phoenix’s `<.form>`, `for={%{}}` supplies the required empty form-data source and Phoenix adds the CSRF token automatically. Values in `for` are not submitted by themselves, so the clicked button carries the selected user key through its `name` and `value`:

```elixir
defmodule MyAppWeb.DevAuthLive do
  use MyAppWeb, :live_view

  alias MyApp.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    users = User |> AshAuthenticationDevUsers.list()
    socket = socket |> assign(users: users)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main>
      <h1>Choose a user</h1>

      <.form
        :for={{key, user} <- @users}
        for={%{}}
        action="/dev/auth/sign-in"
        method="post"
      >
        <button name="user" type="submit" value={key}>{user.display_name}</button>
      </.form>
    </main>
    """
  end
end
```

The same picker can use raw HTML forms, but then each POST form must include the CSRF token explicitly:

```heex
<form
  :for={{key, user} <- @users}
  action="/dev/auth/sign-in"
  method="post"
>
  <input
    name="_csrf_token"
    type="hidden"
    value={Plug.CSRFProtection.get_csrf_token()}
  />
  <button name="user" type="submit" value={key}>{user.display_name}</button>
</form>
```

The strategy is disabled by default and should not be enabled in production.
