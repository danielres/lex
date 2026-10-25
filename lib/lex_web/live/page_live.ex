defmodule LexWeb.PageLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Ash.Error
  alias Ash.Error.Query.NotFound
  alias Ash.Notifier.Notification
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias LexWeb.PageLive.Editing
  alias LexWeb.PageLive.WikiLinkMap

  delegate(:editing, Editing, info: false)
  delegate(:wiki_link_map, WikiLinkMap, info: false)

  @impl true
  def mount(params, session, socket) do
    if connected?(socket), do: Page.subscribe()
    socket = delegate_mount(socket, params, session)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"page_slug" => slug}, _uri, socket) do
    case Page.open(slug) do
      {:ok, page} ->
        socket =
          socket
          |> assign(page: page)
          |> Editing.reload(page)
          |> WikiLinkMap.reload()

        {:noreply, socket}

      {:error, %Error.Invalid{}} ->
        raise NotFound, resource: Page, primary_key: %{slug: slug}

      {:error, error} ->
        raise error
    end
  end

  @impl true
  def handle_info(
        %Notification{resource: PageDocument, action: %{name: action}},
        socket
      )
      when action in [:save, :save_snapshot] do
    {:noreply, socket}
  end

  def handle_info(
        %Notification{resource: Page, action: %{name: :create}},
        socket
      ) do
    socket = WikiLinkMap.reload(socket)

    {:noreply, socket}
  end

  def handle_info(
        %Notification{resource: Page, action: %{name: :rename}, data: renamed_page},
        socket
      ) do
    current_page = socket.assigns.page

    socket = WikiLinkMap.reload(socket)

    if current_page.id == renamed_page.id do
      socket =
        socket
        |> assign(page: renamed_page)
        |> Editing.reload(renamed_page)
        |> push_event("page_title_blur", %{})
        |> push_patch(to: ~p"/wiki/#{renamed_page.slug}")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active="page">
      <div class="flex justify-between pt-6 gap-4 pb-4">
        <Editing.Title.render editing={@editing} page={@page} />
        <Editing.ButtonToggle.render editing={@editing} />
      </div>

      <div
        class="lexical-playground"
        data-checkpoint-event={Editing.checkpoint_event()}
        data-document-id={@page.id}
        data-editable={to_string(@editing.enabled?)}
        data-ensure-page-event={WikiLinkMap.ensure_event()}
        data-pages={WikiLinkMap.encode(@wiki_link_map)}
        data-resolve-page-event={WikiLinkMap.resolve_event()}
        data-snapshot-request-event={Editing.snapshot_request_event()}
        id={"lexical-editor-#{@page.id}"}
        phx-hook="LexicalEditor"
        phx-update="ignore"
      >
      </div>
    </Layouts.app>
    """
  end
end
