defmodule LexWeb.Layouts.Drawer do
  use LexWeb, :html

  use LiveDelegate, path: [:ui]

  alias LexWeb.Components.Avatar
  alias LexWeb.Layouts.ThemeToggle
  alias LexWeb.Presences

  attr :dom_id, :string, required: true
  attr :open?, :boolean, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "sm:grid sm:grid-cols-[auto_1fr]",
      "h-full"
    ]}>
      <div class="order-2">
        {render_slot(@inner_block)}
      </div>

      <.backdrop open?={@open?} />

      <div class={[
        @open? && "w-42",
        !@open? && "w-12 -left-4",
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

        <div class="stacked">
          <div class={[
            @open? && "opacity-100",
            !@open? && "opacity-0 pointer-events-none",
            "transition",
            "pt-2 pb-4 pl-4 pr-4"
          ]}>
            <.presences {assigns} />
          </div>

          <div class={[
            !@open? && "opacity-100",
            @open? && "opacity-0 pointer-events-none",
            "transition",
            "p-4"
          ]}>
            <% count = @presences.data |> length() %>

            <button
              type="button"
              phx-click={delegate_event("toggle_drawer")}
              class={[
                "indicator",
                "tooltip tooltip-right",
                "cursor-pointer"
              ]}
              data-tip={"#{count} members online"}
            >
              <span class={[
                "indicator-item",
                "badge badge-xs",
                count > 1 && "badge-accent",
                "font-semibold"
              ]}>{count}</span>
              <.icon name="hero-users-micro" />
            </button>
          </div>
        </div>

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
      phx-click={delegate_event("toggle_drawer")}
      aria-label="open sidebar"
      class={[
        "sm:hidden",
        "cursor-pointer",
        !@open? && "pointer-events-none",
        "transition",
        @open? && "bg-black/20 backdrop-blur",
        "fixed",
        "inset-0"
      ]}
    ></button>
    """
  end

  attr :class, :string, default: ""

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
          navigate={~p"/"}
          class={[
            link_class,
            @active == "dashboard" && active_class
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
          navigate={~p"/wiki/home"}
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

  defp presences(assigns) do
    ~H"""
    <div class={[
      "is-drawer-close:hidden",
      "space-y-2"
    ]}>
      <h3 class="flex items-baseline justify-between">
        <span class="small-caps tracking-wide">Online now</span>
        <span class="badge badge-xs">{@presences.data |> length()}</span>
      </h3>

      <div class="flex flex-wrap gap-1 w-31">
        <Presences.render presences={@presences} />
      </div>
    </div>
    """
  end
end
