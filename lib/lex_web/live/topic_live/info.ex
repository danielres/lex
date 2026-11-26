defmodule LexWeb.TopicLive.Info do
  use LexWeb, :live_view
  use LiveDelegate, path: [:info]

  alias LexWeb.Components.Avatar
  alias LexWeb.TopicLive.EditTitle
  alias LexWeb.Router.Path

  @impl true
  def handle_event("toggle", _, socket) do
    live_action =
      case socket.assigns.live_action do
        action when action in [:info, :edit_title] -> :show
        _ -> :info
      end

    socket = socket |> assign(live_action: live_action)

    {:noreply, socket}
  end

  defp path_preview(scope, topic) do
    path = Path.to(scope, topic) |> String.split("/") |> Enum.slice(2..9) |> Enum.join("/")
    "/" <> path
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h2 class={[
          "small-caps text-lg",
          "flex items-center gap-2"
        ]}>
          <span>Name and path</span>
          <EditTitle.button_edit :if={Ash.can?({@topic, :update}, @scope)} />
        </h2>

        <div class="ml-4">
          <div class="flex items-baseline gap-2">
            {@topic.name}
          </div>
          <div class="opacity-80 font-mono">{path_preview(@scope, @topic)}</div>
        </div>
      </div>

      <hr class="text-base-content/20 my-4" />

      <div
        class="space-y-1"
        data-testid="topic-author"
      >
        <h2 class="small-caps text-lg">Created by</h2>
        <div class="flex items-baseline gap-2 ml-4">
          <Avatar.render user={@topic.author} />
          <span class="opacity-100">{@topic.author.display_name}</span>
          <span class="text-sm">{Utils.Time.relative(@topic.inserted_at)}</span>
        </div>
      </div>
    </div>
    """
  end

  attr :active?, :boolean, required: true

  def button_toggle(assigns) do
    ~H"""
    <button
      aria-label="Show topic info"
      class={[
        "btn btn-xs btn-circle",
        @active? && "btn-info"
      ]}
      data-testid="topic-info-toggle"
      title="Topic info"
      phx-click={delegate_event("toggle")}
    >
      <.icon name="hero-information-circle-micro" />
    </button>
    """
  end
end
