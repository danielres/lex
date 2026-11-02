defmodule LexWeb.Layouts.Navbar do
  use LexWeb, :html

  alias LexWeb.Components.Avatar
  alias LexWeb.Components.Tooltip
  alias LexWeb.UI

  attr :drawer_open?, :boolean, required: true
  attr :space, :map, required: true
  attr :user, :map, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "bg-base-300",
      "p-2 pr-4 max-sm:pl-0",
      "flex items-center gap-3",
      "border-b border-base-content/20"
    ]}>
      <.toggle_button {assigns} />
      <span class="grow">{@space.slug}</span>

      <Tooltip.render alignment="end">
        <Avatar.render user={@user} />
        <:tooltip>{@user.display_name}</:tooltip>
      </Tooltip.render>
    </div>
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
