defmodule LexWeb.PageLive.WikiLinkMap do
  use LexWeb, :live_view
  use LiveDelegate, path: [:wiki_link_map]

  alias Lex.Wiki.Page

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{pages: []})
  end

  def reload(socket) do
    scope = socket.assigns.scope
    pages = Page.list!(scope: scope)

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
    scope = socket.assigns.scope
    space = socket.assigns.space

    scope
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
    scope = socket.assigns.scope
    space = socket.assigns.space

    case Page.get(id, scope: scope) do
      {:ok, page} ->
        reference = space |> page_reference(page)

        {:reply, %{ok: true, page: reference}, socket}

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
