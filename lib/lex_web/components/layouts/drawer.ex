defmodule LexWeb.Layouts.Drawer do
  use LexWeb, :html

  alias LexWeb.Layouts.ThemeToggle
  alias LexWeb.PresencesLive
  alias LexWeb.UI

  attr :collaborator, :map, required: true
  attr :open?, :boolean, required: true
  attr :socket, :any, required: true
  attr :space, :map, required: true
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div
      class={[
        "sm:grid sm:grid-cols-[auto_1fr]",
        "h-full"
      ]}
      data-drawer-open={to_string(@open?)}
      data-testid="drawer"
    >
      <div class="order-2 max-sm:mt-14">
        {render_slot(@inner_block)}
      </div>

      <.backdrop open?={@open?} />

      <div class={[
        "max-sm:z-50",
        @open? && "w-42",
        !@open? && "w-12 overflow-hidden",
        "max-sm:fixed",
        "max-sm:inset-0",
        !@open? && "max-sm:-left-13",
        "transition-[width] translition-[left] duration-200 ease-in-out",
        "bg-base-300/50 backdrop-blur-lg",
        "border-r border-base-100"
      ]}>
        <div class="p-2 py-4">
          <.main_links {assigns} />
        </div>

        <.separator />

        {live_render(@socket, PresencesLive,
          container: {:div, class: "stacked", data: [testid: "presences-live"]},
          id: "app-presences",
          session: %{"collaborator" => @collaborator},
          sticky: true
        )}

        <.separator class={[
          @open? && "opacity-100",
          !@open? && "opacity-0",
          "transition"
        ]} />

        <div class={[
          @open? && "opacity-100",
          !@open? && "opacity-0",
          "transition",
          "mx-auto w-fit",
          "p-2"
        ]}>
          <ThemeToggle.render />
        </div>
      </div>
    </div>
    """
  end

  def backdrop(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={UI.toggle_drawer_event()}
      aria-label="open sidebar"
      class={[
        "sm:hidden",
        "cursor-pointer",
        !@open? && "pointer-events-none",
        "transition",
        @open? && "bg-base-200/50 Xbackdrop-blur-xs",
        "fixed",
        "inset-0"
      ]}
    ></button>
    """
  end

  attr :class, :any, default: nil

  defp separator(assigns) do
    ~H"""
    <hr class={[
      "border-base-content/20",
      @class
    ]} />
    """
  end

  defp main_links(assigns) do
    ~H"""
    <ul class="grid gap-2">
      <% link_class = [
        !@open? && "tooltip",
        !@open? && "tooltip-right",
        !@open? && "aspect-square",
        !@open? && "justify-center",
        "px-2",
        "font-semibold",
        "flex items-center gap-2",
        "h-8 rounded",
        "text-sm"
      ] %>

      <% active_class = "bg-info text-white" %>

      <li>
        <.link
          navigate={~p"/#{@space.slug}"}
          class={[
            link_class,
            @active == "space" && active_class
          ]}
          data-tip="Dashboard"
        >
          <.icon name="hero-squares-2x2-solid" />
          <span :if={@open?}>
            Dashboard
          </span>
        </.link>
      </li>

      <li>
        <.link
          navigate={~p"/#{@space.slug}/wiki/home"}
          class={[
            link_class,
            @active == "page" && active_class,
            @active == "wiki" && active_class
          ]}
          data-tip="Wiki"
        >
          <.icon name="hero-book-open-mini" />
          <span :if={@open?}>
            Wiki
          </span>
        </.link>
      </li>
    </ul>
    """
  end
end
