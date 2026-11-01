defmodule LexWeb.Layouts.Drawer do
  use LexWeb, :html

  alias LexWeb.Components.Avatar
  alias LexWeb.Layouts.ThemeToggle
  alias LexWeb.Presences

  attr :dom_id, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="drawer sm:drawer-open">
      <input
        id={@dom_id}
        type="checkbox"
        class="drawer-toggle inline"
        checked={false}
      />

      <div class="drawer-content p-4 sm:px-8">
        {render_slot(@inner_block)}
      </div>

      <div class="drawer-side is-drawer-close:overflow-visible h-auto">
        <label for={@dom_id} aria-label="close sidebar" class="drawer-overlay"></label>

        <div class={[
          "flex min-h-full flex-col items-start bg-base-300/50 backdrop-blur",
          "is-drawer-close:w-13 is-drawer-open:w-40",
          "border-r border-base-100",
          "max-sm:min-h-svh"
        ]}>
          <!-- Sidebar content here -->
          <div class="w-full">
            <div class="p-2"><.main_links {assigns} /></div>

            <% render_presences? = @presences.data |> length() > 1 %>

            <.separator :if={render_presences?} />

            <div :if={render_presences?} class="pt-2 pb-4 pl-4 pr-4">
              <.presences {assigns} />
            </div>

            <.separator class="is-drawer-close:hidden" />

            <div class={[
              "mx-auto w-fit",
              "p-2",
              "is-drawer-close:hidden"
            ]}>
              <ThemeToggle.render />
            </div>
          </div>
        </div>
      </div>
    </div>
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
        "is-drawer-close:tooltip",
        "is-drawer-close:tooltip-right",
        "is-drawer-close:aspect-square",
        "is-drawer-close:justify-center",
        "is-drawer-open:px-2",
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
          <span class="is-drawer-close:hidden">Dashboard</span>
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
          <span class="is-drawer-close:hidden">Wiki</span>
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
        <span class="small-caps tracking-wide">Online</span>
        <span class="badge badge-xs">{@presences.data |> length()}</span>
      </h3>

      <div class="flex flex-wrap gap-1 w-31">
        <Presences.render presences={@presences} />
      </div>
    </div>
    """
  end
end
