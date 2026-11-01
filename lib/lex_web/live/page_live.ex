defmodule LexWeb.PageLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Ash.Error
  alias Ash.Error.Query.NotFound
  alias Ash.Notifier.Notification
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias LexWeb.PageLive.Editing
  alias LexWeb.PageLive.Revisions
  alias LexWeb.PageLive.WikiLinkMap
  alias LexWeb.UI

  delegate(:editing, Editing, info: false)
  delegate(:revisions, Revisions, info: false)
  delegate(:wiki_link_map, WikiLinkMap, info: false)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    if connected?(socket), do: Page.subscribe()
    socket = delegate_mount(socket, params, session)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"page_slug" => slug} = params, _uri, socket) do
    case Page.open(slug) do
      {:ok, page} ->
        socket =
          socket
          |> assign(page: page)
          |> Editing.reload(page)
          |> Revisions.reload(page, params["revision_id"])
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
        %Notification{resource: PageRevision, action: %{name: :create}, data: revision},
        socket
      ) do
    socket =
      if revision.page_id == socket.assigns.page.id do
        Revisions.reload(socket, socket.assigns.page, requested_revision_id(socket))
        |> Toast.put_toast(:success, "Page saved", duration: 3000)
      else
        socket
      end

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

    live_action = socket.assigns.live_action
    socket = WikiLinkMap.reload(socket)

    if current_page.id == renamed_page.id do
      socket =
        socket
        |> assign(page: renamed_page)
        |> Editing.reload(renamed_page)
        |> push_event("page_title_blur", %{})

      socket =
        if live_action == :editing do
          socket
        else
          push_patch(socket, to: page_path(socket, renamed_page))
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="page"
      flash={@flash}
      socket={@socket}
      user={@collaborator}
      ui={@ui}
    >
      <div class="text-base-content/50">
        <.link class="hover:text-base-content transition" navigate={~p"/wiki"}>Wiki</.link>
        <.icon name="hero-chevron-right-micro" class="opacity-50" />
      </div>
      <div class={[
        "flex justify-between gap-4 mb-4",
        "pb-2 border-b-2 border-base-content/10"
      ]}>
        <Editing.Title.render editing={@editing} live_action={@live_action} page={@page} />

        <div class="flex gap-2">
          <Revisions.ButtonToggle.render active?={@live_action == :revisions} page={@page} />
          <Editing.ButtonToggle.render editing={@editing} live_action={@live_action} />
        </div>
      </div>

      <div
        class={[
          @live_action == :revisions && "hidden",
          @live_action != :editing && "mt-12",
          "max-w-[90ch]"
        ]}
        id="current-page-editor"
      >
        <div
          class="lexical-playground"
          data-checkpoint-event={Editing.checkpoint_event()}
          data-collaborator-display-name={@collaborator.display_name}
          data-collaborator-hue={@collaborator.hue}
          data-document-id={@page.id}
          data-editable={to_string(@live_action == :editing && !@editing.checkpointing?)}
          data-ensure-page-event={WikiLinkMap.ensure_event()}
          data-pages={WikiLinkMap.encode(@wiki_link_map)}
          data-resolve-page-event={WikiLinkMap.resolve_event()}
          data-restore-checkpoint-event={Revisions.checkpoint_event()}
          data-restore-preserve-event={Revisions.preserve_event()}
          data-restore-request-event={Revisions.restore_request_event()}
          data-snapshot-request-event={Editing.snapshot_request_event()}
          id={"lexical-editor-#{@page.id}"}
          phx-hook="LexicalEditor"
          phx-update="ignore"
        >
        </div>
      </div>

      <section :if={@live_action == :revisions} id="page-revisions" class="max-w-[80ch]">
        <Revisions.render
          collaborator={@collaborator}
          data-pages={WikiLinkMap.encode(@wiki_link_map)}
          page={@page}
          revisions={@revisions}
          wiki_link_map={@wiki_link_map}
        />
      </section>
    </Layouts.app>
    """
  end

  defp requested_revision_id(%{assigns: %{live_action: :revisions, revisions: revisions}}) do
    revisions.requested_id
  end

  defp requested_revision_id(_socket), do: nil

  defp page_path(
         %{assigns: %{live_action: :revisions, revisions: %{requested_id: revision_id}}},
         page
       )
       when revision_id != nil,
       do: ~p"/wiki/#{page.slug}/revisions/#{revision_id}"

  defp page_path(%{assigns: %{live_action: :revisions}}, page),
    do: ~p"/wiki/#{page.slug}/revisions"

  defp page_path(_socket, page), do: ~p"/wiki/#{page.slug}"
end
