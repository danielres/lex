defmodule LexWeb.Layouts.Navbar do
  use LexWeb, :html

  use LiveDelegate, path: [:ui]

  alias LexWeb.Components.Avatar
  alias LexWeb.Layouts.ThemeToggle
  alias LexWeb.Presences

  attr :drawer_open?, :boolean, required: true

  def render(assigns) do
    ~H"""
    <div class="bg-base-300 items-center flex px-2 py-2 gap-3 border-b border-base-100">
      <.toggle_button {assigns} />
      <span class="grow">Berlin hikers</span>
      <Avatar.render user={@user} />
    </div>
    """
  end

  attr :drawer_open?, :boolean, required: true

  def toggle_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={delegate_event("toggle_drawer")}
      aria-label="open sidebar"
      class={[
        "stacked",
        "hover:bg-base-100 transition",
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
    """
  end
end
