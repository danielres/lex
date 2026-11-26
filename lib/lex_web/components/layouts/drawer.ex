defmodule LexWeb.Layouts.Drawer do
  use LexWeb, :html

  alias LexWeb.Components
  alias LexWeb.PresencesLive
  alias LexWeb.Router.Path
  alias LexWeb.UI

  attr :active, :string, required: true
  attr :open?, :boolean, required: true
  attr :scope, :map, required: true
  attr :socket, :any, required: true
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <Components.Drawer.render
      open?={@open?}
      close_event={UI.toggle_drawer_event()}
    >
      {render_slot(@inner_block)}

      <:aside>
        <div class="p-2 py-4">
          <.main_links
            active={@active}
            open?={@open?}
            scope={@scope}
          />
        </div>

        <.separator />

        <.presences scope={@scope} socket={@socket} />
      </:aside>
    </Components.Drawer.render>
    """
  end

  defp presences(assigns) do
    ~H"""
    {live_render(@socket, PresencesLive,
      container: {:div, class: "stacked", data: [testid: "presences-live"]},
      id: "app-presences",
      session: %{"scope" => @scope},
      sticky: true
    )}
    """
  end

  attr :visible?, :boolean, default: true

  defp separator(assigns) do
    ~H"""
    <hr class={[
      "border-base-content/30",
      @visible? && "opacity-100",
      !@visible? && "opacity-0",
      "transition"
    ]} />
    """
  end

  attr :active, :string, required: true
  attr :open?, :boolean, required: true
  attr :scope, :map, required: true

  defp main_links(assigns) do
    ~H"""
    <ul class="grid gap-1.5">
      <% link_class = [
        !@open? && "aspect-square",
        !@open? && "justify-center",
        "px-2",
        "font-semibold",
        "flex items-center gap-2",
        "h-8 rounded",
        "text-sm",
        "transition"
      ] %>

      <% non_active_class = "opacity-50 hover:opacity-100" %>

      <li>
        <.link
          navigate={Path.wiki_home(@scope)}
          class={[
            link_class,
            @active != "wiki" && non_active_class
          ]}
        >
          <.icon name="hero-book-open-mini" />
          <span :if={@open?}>Wiki</span>
        </.link>
      </li>

      <li>
        <.link
          navigate={Path.topics(@scope)}
          class={[
            link_class,
            @active != "topics" && non_active_class
          ]}
        >
          <.icon name="hero-tag-mini" />
          <span :if={@open?}>Topics</span>
        </.link>
      </li>

      <li>
        <.link
          navigate={Path.members(@scope)}
          class={[
            link_class,
            @active != "members" && non_active_class
          ]}
        >
          <.icon name="hero-user-group-mini" />
          <span :if={@open?}>Members</span>
        </.link>
      </li>
    </ul>
    """
  end
end
