defmodule LexWeb.PageLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Ash.Notifier.Notification
  alias Lex.Wiki
  alias LexWeb.PageLive.Creation
  alias LexWeb.PageLive.EditTitle
  alias LexWeb.PageLive.Editing
  alias LexWeb.PageLive.Info
  alias LexWeb.PageLive.Navigation
  alias LexWeb.PageLive.Notifications
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
  def handle_params(params, _uri, socket),
    do: Navigation.handle_params(socket, params)

  @impl true
  def handle_info(%Notification{} = notification, socket),
    do: Notifications.handle(socket, notification)

  def dialog?(live_action) do
    live_action == :info ||
      live_action == :edit_title ||
      live_action == :revisions
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="wiki"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <:page_head>
        <Layouts.page_head
          :if={@page}
          dialog?={dialog?(@live_action)}
          close_event={@live_action == :info && "close_dialog"}
        >
          <:crumb><.link navigate={Path.wiki(@scope)} class="clickable">Wiki</.link></:crumb>
          <:title>{@page.title}</:title>

          <:actions>
            <.action_buttons
              editing={@editing}
              live_action={@live_action}
              page={@page}
              scope={@scope}
            />
          </:actions>

          <:dialog>
            <EditTitle.render_form :if={@live_action == :edit_title} edit_title={@edit_title} />
            <Info.render :if={@live_action == :info} page={@page} scope={@scope} />
            <Revisions.render_dialog :if={@live_action == :revisions} {assigns} />
          </:dialog>
        </Layouts.page_head>
      </:page_head>

      <Creation.render :if={@page == nil} creation={@creation} scope={@scope} />

      <div :if={@page} class="stacked flex-1">
        <section
          class={[
            "flex min-w-0 flex-col",
            @live_action == :revisions && "invisible",
            @live_action != :editing && "max-sm:px-2 max-sm:py-4 sm:p-6 pb-0 bg-card rounded-box"
          ]}
          id="current-page-editor"
          inert={@live_action == :revisions}
        >
          <.editor
            editable?={can?(@scope, :edit_pages) && @live_action == :editing && !@editing.saving?}
            page={@page}
            page_repository={@page_repository}
            scope={@scope}
          />
        </section>

        <section
          :if={@live_action == :revisions}
          class="w-full min-w-0"
          id="page-revisions"
        >
          <.revision
            page={@page}
            page_repository={@page_repository}
            revisions={@revisions}
            scope={@scope}
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :page, Lex.Wiki.Page, required: true
  attr :page_repository, :map, required: true
  attr :revisions, :map, required: true
  attr :scope, Lex.Scope, required: true

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

  attr :editable?, :boolean, required: true
  attr :page, Lex.Wiki.Page, required: true
  attr :page_repository, :map, required: true
  attr :scope, Lex.Scope, required: true

  defp editor(assigns) do
    ~H"""
    <div
      class="lexical-editor"
      data-testid="page-editor"
      data-save-event={Editing.save_event()}
      data-collaborator-display-name={@scope.user.display_name}
      data-collaborator-hue={@scope.user.hue}
      data-document-id={@page.id}
      data-editable={@editable? |> to_string()}
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

  attr :editing, :map, required: true
  attr :live_action, :atom, required: true
  attr :page, Lex.Wiki.Page, required: true
  attr :scope, Lex.Scope, required: true

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

  def handle_event("close_dialog", _params, socket) do
    {:noreply, assign(socket, :live_action, :view)}
  end
end
