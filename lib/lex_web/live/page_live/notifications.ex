defmodule LexWeb.PageLive.Notifications do
  use LexWeb, :live_view

  alias Ash.Notifier.Notification
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias LexWeb.Live.Rename
  alias LexWeb.PageLive.Navigation
  alias LexWeb.PageLive.PageRepository
  alias LexWeb.PageLive.Revisions
  alias LexWeb.Router.Path

  def handle(
        socket,
        %Notification{
          resource: PageDocument,
          action: %{name: :save},
          data: %{document_key: "main"} = page_document
        }
      ) do
    page_repository = socket.assigns.page_repository
    page_id = page_document.page_id

    socket =
      if page_repository |> PageRepository.includes?(page_id) do
        socket
        |> push_event(PageRepository.content_updated_event(), %{
          content_hash: page_document.content_hash,
          lexical_state: page_document.lexical_state,
          page_id: page_document.page_id
        })
      else
        socket
      end

    {:noreply, socket}
  end

  def handle(socket, %Notification{resource: PageDocument}), do: {:noreply, socket}

  def handle(
        socket,
        %Notification{resource: PageRevision, action: %{name: :create}, data: revision}
      ) do
    page = socket.assigns.page

    socket =
      case page do
        %{id: page_id} = page when revision.page_id == page_id ->
          revision_number = requested_revision_number(socket)

          socket
          |> Revisions.reload(page, revision_number)
          |> Toast.put_toast(:success, "Page saved", duration: 3000)

        _page ->
          socket
      end

    {:noreply, socket}
  end

  def handle(
        socket,
        %Notification{resource: Page, action: %{name: :create}, data: created_page}
      ) do
    page = socket.assigns.page
    space = socket.assigns.scope.space
    creation = socket.assigns.creation

    socket =
      if page == nil and created_page.space_id == space.id and created_page.slug == creation.slug do
        socket |> Navigation.load_page(created_page, nil)
      else
        socket |> PageRepository.reload()
      end

    {:noreply, socket}
  end

  def handle(
        socket,
        %Notification{resource: Page, action: %{name: :rename}, data: renamed_page}
      ) do
    %{page: previous, live_action: live_action, scope: scope} = socket.assigns

    socket =
      if renamed_page.space_id == scope.space.id do
        socket |> PageRepository.reload()
      else
        socket
      end

    with %Page{id: id} <- previous,
         true <- id == renamed_page.id,
         %Page{} = page <- Enum.find(socket.assigns.page_repository.pages, &(&1.id == id)),
         true <- previous.name != page.name or previous.slug != page.slug do
      path = if live_action != :editing, do: Navigation.page_path(socket, page)

      socket =
        socket
        |> assign(:page, page)
        |> Rename.apply_change(previous, page, "Page", path)

      {:noreply, socket}
    else
      _other -> {:noreply, socket}
    end
  end

  def handle(socket, %Notification{resource: Page, action: %{name: :destroy}, data: page}) do
    %{page: current_page, scope: scope} = socket.assigns

    socket =
      if current_page && current_page.id == page.id do
        socket
        |> Toast.put_toast(:info, "Page #{page.name} was deleted")
        |> push_navigate(to: Path.wiki(scope), replace: true)
      else
        PageRepository.reload(socket)
      end

    {:noreply, socket}
  end

  defp requested_revision_number(%{
         assigns: %{live_action: :revisions, revisions: revisions}
       }) do
    revisions.requested_number
  end

  defp requested_revision_number(_socket), do: nil
end
