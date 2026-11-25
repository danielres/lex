defmodule LexWeb.PageLive.Notifications do
  use LexWeb, :live_view

  alias Ash.Notifier.Notification
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias LexWeb.PageLive.EditTitle
  alias LexWeb.PageLive.Navigation
  alias LexWeb.PageLive.PageRepository
  alias LexWeb.PageLive.Revisions

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
    current_page = socket.assigns.page
    live_action = socket.assigns.live_action
    socket = socket |> PageRepository.reload()

    if current_page != nil and current_page.id == renamed_page.id do
      socket =
        socket
        |> assign(page: renamed_page)
        |> EditTitle.reload(renamed_page)
        |> push_event("page_title_blur", %{})

      socket =
        if live_action == :editing do
          socket
        else
          path = socket |> Navigation.page_path(renamed_page)

          socket |> push_patch(to: path)
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp requested_revision_number(%{
         assigns: %{live_action: :revisions, revisions: revisions}
       }) do
    revisions.requested_number
  end

  defp requested_revision_number(_socket), do: nil
end
