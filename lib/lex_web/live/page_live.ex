defmodule LexWeb.PageLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Ash.Error
  alias Ash.Error.Query.NotFound
  alias Ash.Notifier.Notification
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias LexWeb.PageLive.Creation
  alias LexWeb.PageLive.Editing
  alias LexWeb.PageLive.Revisions
  alias LexWeb.PageLive.WikiLinkMap
  alias LexWeb.Space
  alias LexWeb.UI

  delegate(:creation, Creation, info: false)
  delegate(:editing, Editing, info: false)
  delegate(:revisions, Revisions, info: false)
  delegate(:wiki_link_map, WikiLinkMap, info: false)
  delegate(:space, Space)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    if connected?(socket), do: Page.subscribe()
    socket = socket |> delegate_mount(params, session)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"page_slug" => slug} = params, _uri, socket) do
    space = socket.assigns.space

    space
    |> Page.fetch_by_slug(slug)
    |> case do
      {:ok, nil} when slug == "home" ->
        page = space |> Page.ensure!("Home")
        socket = socket |> load_page(page, params["revision_id"])

        {:noreply, socket}

      {:ok, nil} ->
        socket =
          socket
          |> assign(page: nil)
          |> Creation.reload(space, slug)

        {:noreply, socket}

      {:ok, page} ->
        socket = socket |> load_page(page, params["revision_id"])

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
    page = socket.assigns.page

    socket =
      case page do
        %{id: page_id} = page when revision.page_id == page_id ->
          revision_id = requested_revision_id(socket)

          socket
          |> Revisions.reload(page, revision_id)
          |> Toast.put_toast(:success, "Page saved", duration: 3000)

        _page ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info(
        %Notification{resource: Page, action: %{name: :create}, data: created_page},
        socket
      ) do
    page = socket.assigns.page
    space = socket.assigns.space
    creation = socket.assigns.creation

    socket =
      if page == nil and created_page.space_id == space.id and created_page.slug == creation.slug do
        socket |> load_page(created_page, nil)
      else
        socket |> WikiLinkMap.reload()
      end

    {:noreply, socket}
  end

  def handle_info(
        %Notification{resource: Page, action: %{name: :rename}, data: renamed_page},
        socket
      ) do
    current_page = socket.assigns.page

    live_action = socket.assigns.live_action
    socket = socket |> WikiLinkMap.reload()

    if current_page != nil and current_page.id == renamed_page.id do
      socket =
        socket
        |> assign(page: renamed_page)
        |> Editing.reload(renamed_page)
        |> push_event("page_title_blur", %{})

      socket =
        if live_action == :editing do
          socket
        else
          path = page_path(socket, renamed_page)

          socket |> push_patch(to: path)
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
      space={@space}
      user={@collaborator}
      ui={@ui}
      editing?={@live_action == :editing}
    >
      <div class="fixed sm:sticky top-14 sm:top-2 right-2 z-30 sm:w-full sm:flex sm:justify-end sm:h-0">
        <div :if={@page} class="flex gap-2 bg-base-200/50 backdrop-blur p-2 rounded-full">
          <Revisions.ButtonToggle.render
            active?={@live_action == :revisions}
            page={@page}
            space={@space}
          />
          <Editing.ButtonToggle.render editing={@editing} live_action={@live_action} />
        </div>
      </div>

      <div :if={@page != nil} class="text-base-content/50">
        <.link class="hover:text-base-content transition" navigate={~p"/#{@space.slug}/wiki"}>
          Wiki
        </.link>
        <.icon name="hero-chevron-right-micro" class="opacity-50" />
      </div>

      <Creation.render :if={@page == nil} creation={@creation} />

      <div :if={@page} class="min-w-0">
        <div class="mb-4 pb-2 border-b-2 border-base-content/10">
          <Editing.Title.render editing={@editing} live_action={@live_action} page={@page} />
        </div>

        <div
          class={[
            @live_action == :revisions && "hidden",
            @live_action != :editing && "mt-12",
            "min-w-0 max-w-[90ch]"
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
            data-pages={WikiLinkMap.encode(@wiki_link_map, @space)}
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

        <section
          :if={@live_action == :revisions}
          class="w-full min-w-0 max-w-[80ch]"
          id="page-revisions"
        >
          <Revisions.render
            collaborator={@collaborator}
            data-pages={WikiLinkMap.encode(@wiki_link_map, @space)}
            page={@page}
            revisions={@revisions}
            space={@space}
            wiki_link_map={@wiki_link_map}
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp requested_revision_id(%{assigns: %{live_action: :revisions, revisions: revisions}}) do
    revisions.requested_id
  end

  defp requested_revision_id(_socket), do: nil

  defp load_page(socket, page, revision_id) do
    socket
    |> assign(page: page)
    |> Editing.reload(page)
    |> Revisions.reload(page, revision_id)
    |> WikiLinkMap.reload()
  end

  defp page_path(
         %{
           assigns: %{
             live_action: :revisions,
             revisions: %{requested_id: revision_id},
             space: %{slug: space_slug}
           }
         },
         page
       )
       when revision_id != nil,
       do: ~p"/#{space_slug}/wiki/#{page.slug}/revisions/#{revision_id}"

  defp page_path(
         %{assigns: %{live_action: :revisions, space: %{slug: space_slug}}},
         page
       ),
       do: ~p"/#{space_slug}/wiki/#{page.slug}/revisions"

  defp page_path(%{assigns: %{space: %{slug: space_slug}}}, page),
    do: ~p"/#{space_slug}/wiki/#{page.slug}"
end
