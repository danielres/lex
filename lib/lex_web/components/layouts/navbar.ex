defmodule LexWeb.Layouts.Navbar do
  use LexWeb, :html

  use LiveDelegate, path: [:ui]

  alias LexWeb.Components.Avatar
  alias LexWeb.Layouts.ThemeToggle
  alias LexWeb.Presences

  attr :drawer_open?, :boolean, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "bg-base-300",
      "p-2 max-sm:pl-0",
      "flex items-center gap-3",
      "border-b border-base-100"
    ]}>
      <div class={[
        "max-sm:fixed",
        "top-1",
        "left-1",
        "z-50"
      ]}>
        <.toggle_button {assigns} />
      </div>
      <span class="grow max-sm:ml-12">Berlin hikers</span>
      <Avatar.render user={@user} />
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
        type="button"
        phx-click={delegate_event("toggle_drawer")}
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
