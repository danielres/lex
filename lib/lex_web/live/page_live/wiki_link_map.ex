defmodule LexWeb.PageLive.WikiLinkMap do
  use LexWeb, :live_view
  use LiveDelegate, path: [:wiki_link_map]

  alias Lex.Wiki.Page

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{pages: []})
  end

  def reload(socket) do
    space = socket.assigns.space
    pages = Page.list!(query: [filter: [space_id: space.id]])

    socket |> delegate_assign(:pages, pages)
  end

  def encode(wiki_link_map, space) do
    wiki_link_map.pages
    |> Enum.map(fn page -> space |> page_reference(page) end)
    |> Jason.encode!()
  end

  def ensure_event, do: delegate_event("ensure")
  def resolve_event, do: delegate_event("resolve")

  @impl true
  def handle_event("ensure", %{"title" => title}, socket) do
    space = socket.assigns.space

    space
    |> Page.ensure(title)
    |> case do
      {:ok, page} ->
        reference = space |> page_reference(page)

        {:reply, %{ok: true, page: reference}, socket}

      {:error, error} ->
        message = Exception.message(error)

        {:reply, %{ok: false, error: message}, socket}
    end
  end

  def handle_event("resolve", %{"id" => id}, socket) do
    space = socket.assigns.space

    case Page.get(id) do
      {:ok, page} when page.space_id == space.id ->
        reference = space |> page_reference(page)

        {:reply, %{ok: true, page: reference}, socket}

      {:ok, _page} ->
        {:reply, %{ok: false}, socket}

      {:error, _error} ->
        {:reply, %{ok: false}, socket}
    end
  end

  defp page_reference(space, page) do
    %{
      id: page.id,
      path: ~p"/#{space.slug}/wiki/#{page.slug}",
      slug: page.slug,
      title: page.title
    }
  end
end
