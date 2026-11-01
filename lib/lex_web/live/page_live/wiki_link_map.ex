defmodule LexWeb.PageLive.WikiLinkMap do
  use LexWeb, :live_view
  use LiveDelegate, path: [:wiki_link_map]

  alias Lex.Wiki.Page

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{pages: []})
  end

  def reload(socket) do
    delegate_assign(socket, :pages, Page.list!())
  end

  def encode(wiki_link_map, space) do
    wiki_link_map.pages
    |> Enum.map(&page_reference(&1, space))
    |> Jason.encode!()
  end

  def ensure_event, do: delegate_event("ensure")
  def resolve_event, do: delegate_event("resolve")

  @impl true
  def handle_event("ensure", %{"title" => title}, socket) do
    case Page.ensure(title) do
      {:ok, page} ->
        {:reply, %{ok: true, page: page_reference(page, socket.assigns.space)}, socket}

      {:error, error} ->
        {:reply, %{ok: false, error: Exception.message(error)}, socket}
    end
  end

  def handle_event("resolve", %{"id" => id}, socket) do
    case Page.get(id) do
      {:ok, page} ->
        {:reply, %{ok: true, page: page_reference(page, socket.assigns.space)}, socket}

      {:error, _error} ->
        {:reply, %{ok: false}, socket}
    end
  end

  defp page_reference(page, space) do
    %{
      id: page.id,
      path: ~p"/#{space.slug}/wiki/#{page.slug}",
      slug: page.slug,
      title: page.title
    }
  end
end
