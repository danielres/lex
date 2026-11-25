defmodule LexWeb.PageLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Ash.Error
  alias Ash.Error.Query.NotFound
  alias Ash.Notifier.Notification
  alias Lex.Wiki
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias LexWeb.PageLive.Creation
  alias LexWeb.PageLive.EditTitle
  alias LexWeb.PageLive.Editing
  alias LexWeb.PageLive.Info
  alias LexWeb.PageLive.PageRepository
  alias LexWeb.PageLive.Revisions
  alias LexWeb.Router.Path
  alias LexWeb.UI

  delegate(:creation, Creation, info: false)
  delegate(:edit_title, EditTitle, info: false)
  delegate(:editing, Editing, info: false)
  delegate(:info, Info, info: false, mount: false)
  delegate(:page_repository, PageRepository, info: false)
  delegate(:revisions, Revisions, info: false)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)
    # socket = socket |> assign(live_action: :edit_title)
    if connected?(socket), do: Wiki.subscribe()
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"page_slug" => slug} = params, _uri, socket) do
    scope = socket.assigns.scope

    scope
    |> Page.fetch_by_slug(slug)
    |> case do
      {:ok, nil} when slug == "home" ->
        socket =
          if scope |> can?(:edit_pages) do
            page = scope |> Page.ensure!("Home")

            socket |> load_page(page, params["revision_number"])
          else
            socket
            |> assign(page: nil)
            |> Creation.reload(scope, slug)
          end

        {:noreply, socket}

      {:ok, nil} ->
        socket =
          socket
          |> assign(page: nil)
          |> Creation.reload(scope, slug)

        {:noreply, socket}

      {:ok, page} ->
        socket = socket |> load_page(page, params["revision_number"])

        {:noreply, socket}

      {:error, %Error.Invalid{}} ->
        raise NotFound, resource: Page, primary_key: %{slug: slug}

      {:error, error} ->
        raise error
    end
  end

  @impl true
  def handle_info(
        %Notification{
          resource: PageDocument,
          action: %{name: :save},
          data: %{document_key: "main"} = page_document
        },
        socket
      ) do
    page_repository = socket.assigns.page_repository
    page_id = page_document.page_id

    socket =
      if page_repository |> PageRepository.includes?(page_id) do
        push_event(socket, PageRepository.content_updated_event(), %{
          content_hash: page_document.content_hash,
          lexical_state: page_document.lexical_state,
          page_id: page_document.page_id
        })
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(%Notification{resource: PageDocument}, socket), do: {:noreply, socket}

  def handle_info(
        %Notification{resource: PageRevision, action: %{name: :create}, data: revision},
        socket
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

  def handle_info(
        %Notification{resource: Page, action: %{name: :create}, data: created_page},
        socket
      ) do
    page = socket.assigns.page
    space = socket.assigns.scope.space
    creation = socket.assigns.creation

    socket =
      if page == nil and created_page.space_id == space.id and created_page.slug == creation.slug do
        socket |> load_page(created_page, nil)
      else
        socket |> PageRepository.reload()
      end

    {:noreply, socket}
  end

  def handle_info(
        %Notification{resource: Page, action: %{name: :rename}, data: renamed_page},
        socket
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
          path = page_path(socket, renamed_page)

          socket |> push_patch(to: path)
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def dialog?(live_action) do
    live_action == :info ||
      live_action == :edit_title ||
      live_action == :revisions
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="page"
      editing?={@live_action == :editing}
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <Creation.render :if={@page == nil} creation={@creation} scope={@scope} />

      <Layouts.page_head
        :if={@page}
        dialog?={dialog?(@live_action)}
      >
        <:title><.link class="clickable" navigate={Path.wiki(@scope)}>Wiki</.link></:title>
        <:title>{@page.title}</:title>
        <:actions><.action_buttons {assigns} /></:actions>
        <:dialog>
          <EditTitle.render_form :if={@live_action == :edit_title} edit_title={@edit_title} />
          <Info.render :if={@live_action == :info} page={@page} scope={@scope} />
          <Revisions.render_dialog :if={@live_action == :revisions} {assigns} />
        </:dialog>
      </Layouts.page_head>

      <div :if={@page}>
        <section
          class={[
            @live_action == :revisions && "hidden",
            @live_action != :editing && "mt-8",
            "min-w-0"
          ]}
          id="current-page-editor"
        >
          <.editor {assigns} />
        </section>

        <section
          :if={@live_action == :revisions}
          class="w-full min-w-0"
          id="page-revisions"
        >
          <.revision {assigns} />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp revision(assigns) do
    ~H"""
    <Revisions.render
      data-save-page-event={PageRepository.save_event()}
      data-load-page-content-event={PageRepository.load_content_event()}
      data-page-id={@page.id}
      data-pages={PageRepository.encode(@page_repository, @scope)}
      data-resolve-page-event={PageRepository.resolve_event()}
      data-space-id={@scope.space.id}
      page={@page}
      revisions={@revisions}
      scope={@scope}
      page_repository={@page_repository}
    />
    """
  end

  defp editor(assigns) do
    ~H"""
    <div
      class="lexical-editor"
      data-testid="page-editor"
      data-save-event={Editing.save_event()}
      data-collaborator-display-name={@scope.user.display_name}
      data-collaborator-hue={@scope.user.hue}
      data-document-id={@page.id}
      data-editable={
        to_string(can?(@scope, :edit_pages) && @live_action == :editing && !@editing.saving?)
      }
      data-save-page-event={PageRepository.save_event()}
      data-ensure-page-event={PageRepository.ensure_event()}
      data-load-page-content-event={PageRepository.load_content_event()}
      data-pages={PageRepository.encode(@page_repository, @scope)}
      data-resolve-page-event={PageRepository.resolve_event()}
      data-restore-commit-event={Revisions.commit_restore_event()}
      data-restore-preserve-event={Revisions.preserve_event()}
      data-restore-request-event={Revisions.restore_request_event()}
      data-save-request-event={Editing.save_request_event()}
      data-space-id={@scope.space.id}
      id={"lexical-editor-#{@page.id}"}
      phx-hook="LexicalEditor"
      phx-update="ignore"
    />
    """
  end

  defp action_buttons(assigns) do
    ~H"""
    <Info.button_toggle active?={@live_action == :info} />

    <Revisions.button_toggle
      active?={@live_action == :revisions}
      page={@page}
      scope={@scope}
    />

    <Editing.button_toggle
      :if={can?(@scope, :edit_pages)}
      editing={@editing}
      active?={@live_action == :editing}
    />
    """
  end

  defp requested_revision_number(%{
         assigns: %{live_action: :revisions, revisions: revisions}
       }) do
    revisions.requested_number
  end

  defp requested_revision_number(_socket), do: nil

  defp load_page(socket, page, revision_number) do
    socket
    |> assign(page: page)
    |> EditTitle.reload(page)
    |> Revisions.reload(page, revision_number)
    |> PageRepository.reload()
  end

  defp page_path(
         %{
           assigns: %{
             live_action: :revisions,
             revisions: %{
               requested_number: revision_number,
               selected: %PageRevision{}
             },
             scope: scope
           }
         },
         page
       )
       when revision_number != nil,
       do: Path.to(scope, page, revision_number)

  defp page_path(
         %{assigns: %{live_action: :revisions, scope: scope}},
         page
       ),
       do: Path.revisions(scope, page)

  defp page_path(%{assigns: %{scope: scope}}, page), do: Path.to(scope, page)
end
