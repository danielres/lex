defmodule LexWeb.TopicLive.Info do
  use LexWeb, :live_view
  use LiveDelegate, path: [:info]

  alias LexWeb.Components.ResourceInfo
  alias LexWeb.Layouts
  alias LexWeb.Live.Rename
  alias LexWeb.Router.Path

  @impl true
  def handle_event("toggle", _, socket) do
    live_action =
      case socket.assigns.live_action do
        action when action in [:info, :rename] -> :show
        _ -> :info
      end

    socket = socket |> Rename.clear() |> assign(live_action: live_action)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <ResourceInfo.container>
      <ResourceInfo.path_preview path={Path.to(@scope, @topic)} />

      <hr class="text-base-content/20 my-4" />

      <ResourceInfo.created_by
        author={@topic.author}
        inserted_at={@topic.inserted_at}
        data-testid="topic-author"
      />
    </ResourceInfo.container>
    """
  end

  attr :active?, :boolean, required: true

  def button_toggle(assigns) do
    ~H"""
    <Layouts.action_button
      active?={@active?}
      title="Topic info"
      data-testid="topic-info-toggle"
      phx-click={delegate_event("toggle")}
      icon="hero-information-circle-micro"
    />
    """
  end
end
