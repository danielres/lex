defmodule LexWeb.MemberLive.Taggings.Sorting do
  use LexWeb, :live_view
  use LiveDelegate, path: [:taggings, :sorting]

  alias Lex.Topics.Tagging
  alias LexWeb.Live.TaggingComponents
  alias LexWeb.Live.TaggingSorting

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, TaggingSorting.load(socket, :member_taggings))
  end

  @impl true
  def handle_event("start", _params, socket) do
    {:noreply, assign(socket, :mode, :sort_taggings)}
  end

  def handle_event("sort", %{"by" => by}, socket) do
    case TaggingSorting.change(socket.assigns.taggings.sorting, by) do
      {:ok, sorting} ->
        scope = socket.assigns.scope
        profile = socket.assigns.profile
        {:ok, groups} = Tagging.present_for_target(profile, sorting, scope: scope)

        socket =
          socket
          |> delegate_assign(sorting)
          |> update(:taggings, &Map.put(&1, :groups, groups))
          |> TaggingSorting.persist(:member_taggings, sorting)

        {:noreply, socket}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <TaggingComponents.sort_controls
      alpha_label="Topic name"
      event={delegate_event("sort")}
      sorting={@sorting}
    />
    """
  end
end
