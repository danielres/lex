defmodule LexWeb.PageLive.PageRepository do
  use LexWeb, :live_view
  use LiveDelegate, path: [:page_repository]

  alias Lex.Collaboration
  alias Lex.Wiki.Page

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{pages: []})
  end

  def reload(socket) do
    scope = socket.assigns.scope
    pages = Page.list!(scope: scope)

    socket |> delegate_assign(:pages, pages)
  end

  def encode(page_repository, scope) do
    page_repository.pages
    |> Enum.map(fn page -> scope.space |> page_reference(page) end)
    |> Jason.encode!()
  end

  def includes?(page_repository, page_id) do
    Enum.any?(page_repository.pages, &(&1.id == page_id))
  end

  def ensure_event, do: delegate_event("ensure")
  def resolve_event, do: delegate_event("resolve")
  def load_content_event, do: delegate_event("load_content")
  def save_event, do: delegate_event("save")
  def content_updated_event, do: "page_content_updated"

  @impl true
  def handle_event("ensure", %{"title" => title}, socket) do
    scope = socket.assigns.scope

    scope
    |> Page.ensure(title)
    |> case do
      {:ok, page} ->
        reference = scope.space |> page_reference(page)

        {:reply, %{ok: true, page: reference}, socket}

      {:error, error} ->
        message = Exception.message(error)

        {:reply, %{ok: false, error: message}, socket}
    end
  end

  def handle_event("resolve", %{"id" => id}, socket) do
    scope = socket.assigns.scope

    case Page.get(id, scope: scope) do
      {:ok, page} ->
        reference = scope.space |> page_reference(page)

        {:reply, %{ok: true, page: reference}, socket}

      {:error, _error} ->
        {:reply, %{ok: false}, socket}
    end
  end

  def handle_event("load_content", %{"id" => id}, socket) do
    scope = socket.assigns.scope

    with {:ok, page} <- Page.get(id, scope: scope),
         {:ok, content} <- scope |> Page.get_document_content(page, "main") do
      {:reply, %{ok: true, content: content}, socket}
    else
      {:error, _error} -> {:reply, %{ok: false}, socket}
    end
  end

  def handle_event(
        "save",
        %{"documents" => documents, "page_id" => page_id},
        socket
      )
      when is_list(documents) do
    scope = socket.assigns.scope

    with {:ok, page} <- Page.get(page_id, scope: scope),
         {:ok, result} <- scope |> Collaboration.save(page, documents) do
      {:reply, %{ok: true, result: result}, socket}
    else
      {:error, reason} -> {:reply, %{ok: false, error: inspect(reason)}, socket}
    end
  end

  def handle_event("save", _params, socket) do
    {:reply, %{ok: false, error: "invalid save"}, socket}
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
