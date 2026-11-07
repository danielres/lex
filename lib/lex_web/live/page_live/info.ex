defmodule LexWeb.PageLive.Info do
  use LexWeb, :live_view
  use LiveDelegate, path: [:info]

  alias LexWeb.Components.Avatar

  @impl true
  def handle_event("toggle", _, socket) do
    live_action =
      case socket.assigns.live_action do
        :info -> :show
        _ -> :info
      end

    socket = socket |> assign(live_action: live_action)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="space-y-2"
      data-testid="page-author"
    >
      <h2>
        <span class="font-bold">Created by</span>
      </h2>
      <div class="flex items-baseline gap-2">
        <Avatar.render user={@page.author} />
        <span class="opacity-100">{@page.author.display_name}</span>
        <span class="text-sm">{Utils.Time.relative(@page.inserted_at)}</span>
      </div>
    </div>
    """
  end

  attr :active?, :boolean, required: true

  def button_toggle(assigns) do
    ~H"""
    <button
      aria-label="Show page info"
      class={[
        "btn btn-sm btn-circle",
        @active? && "btn-info"
      ]}
      title="Browse revisions"
      phx-click={delegate_event("toggle")}
    >
      <.icon name="hero-information-circle-micro" />
    </button>
    """
  end
end
