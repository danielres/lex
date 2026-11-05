defmodule LexWeb.Layouts.Navbar do
  use LexWeb, :html

  alias LexWeb.Components.Avatar
  alias LexWeb.Components.Dropdown
  alias LexWeb.Layouts.ThemeToggle
  alias LexWeb.UI

  attr :drawer_open?, :boolean, required: true
  attr :scope, :map, required: true
  attr :space, :map, required: true

  def render(assigns) do
    ~H"""
    <% current_user = @scope.current_user %>
    <div class={[
      "bg-base-300",
      "p-2 pr-4 max-sm:pl-0",
      "flex items-center gap-3",
      "border-b border-base-content/20"
    ]}>
      <.toggle_button {assigns} />
      <div class="grow">
        <.link
          navigate={~p"/#{@space.slug}"}
          class="opacity-80 hover:opacity-100 transition cursor-pointer"
        >
          {@space.name}
        </.link>
      </div>

      <Dropdown.render id="navbar-user-dropdown">
        <Avatar.render user={current_user} />

        <:content>
          <div class={[
            "bg-base-300",
            "px-4 py-3 mr-4 mt-5",
            "min-w-36",
            "rounded-box",
            "shadow-lg",
            "border border-base-content/20",
            "grid gap-2"
          ]}>
            <div class={[
              "text-sm"
            ]}>
              {current_user.display_name}
            </div>

            <.button_sign_out />

            <hr class={[
              "border-base-content/20",
              "my-2"
            ]} />

            <ThemeToggle.render />
          </div>
        </:content>
      </Dropdown.render>
    </div>
    """
  end

  def button_sign_out(assigns) do
    ~H"""
    <.form for={%{}} action={~p"/sign-out"} method="delete" class="contents">
      <button type="submit" class="btn btn-sm">
        Sign out <.icon name="hero-chevron-right-micro" />
      </button>
    </.form>
    """
  end

  attr :drawer_open?, :boolean, required: true

  def toggle_button(assigns) do
    ~H"""
    <div class={[
      @drawer_open? && "max-sm:hidden"
    ]}>
      <button
        data-testid="drawer-toggle"
        id="drawer-toggle"
        type="button"
        phx-click={UI.toggle_drawer_event()}
        aria-label="open sidebar"
        class={[
          "stacked",
          "bg-base-300 hover:bg-base-100 transition",
          "cursor-pointer",
          "size-8 rounded",
          "flex items-center justify-center"
        ]}
      >
        <.icon
          name="hero-bars-3-micro"
          class={[
            "size-5",
            !@drawer_open? && "opacity-100",
            @drawer_open? && "opacity-0",
            "transition"
          ]}
        />
        <.icon
          name="hero-x-mark-micro"
          class={[
            "size-5",
            @drawer_open? && "opacity-100",
            !@drawer_open? && "opacity-0",
            "transition"
          ]}
        />
      </button>
    </div>
    """
  end
end
