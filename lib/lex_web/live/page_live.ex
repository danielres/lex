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

  delegate(:editing, Editing, info: false)
  delegate(:revisions, Revisions, info: false)
  delegate(:wiki_link_map, WikiLinkMap, info: false)

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
        <div class="flex gap-2">
          <.link
            :if={@live_action == :show}
            aria-label="Browse revisions"
            disabled={@editing.enabled?}
            class="btn btn-square rounded-box"
            patch={~p"/wiki/#{@page.slug}/revisions"}
            title="Browse revisions"
          >
            <.icon name="hero-clock-solid" />
          </.link>
          <.link
            :if={@live_action == :revisions}
            aria-label="Return to current page"
            class="btn btn-square rounded-box btn-info"
            patch={~p"/wiki/#{@page.slug}"}
            title="Return to current page"
          >
            <.icon name="hero-clock-solid" />
          </.link>
          <Editing.ButtonToggle.render disabled={@live_action == :revisions} editing={@editing} />
        </div>
      </div>

      <div
        class={@live_action == :revisions && "hidden"}
        id="current-page-editor"
      >
        <div
          class="lexical-playground"
          data-checkpoint-event={Editing.checkpoint_event()}
          data-document-id={@page.id}
          data-editable={to_string(@editing.enabled?)}
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

      <section :if={@live_action == :revisions} id="page-revisions">
        <div :if={@revisions.selected} class="flex items-center justify-between gap-3 pb-4">
          <div>
            <p class="font-medium">
              Revision {Revisions.position(@revisions)} of {length(@revisions.entries)}
            </p>
            <p class="text-sm opacity-60">{@revisions.selected.inserted_at}</p>
          </div>

          <div class="flex gap-2">
            <.link
              :if={Revisions.previous(@revisions)}
              aria-label="Previous revision"
              class="btn btn-square"
              id="previous-revision"
              patch={~p"/wiki/#{@page.slug}/revisions/#{Revisions.previous(@revisions).id}"}
            >
              <.icon name="hero-chevron-left-micro" class="size-4" />
            </.link>
            <button
              :if={!Revisions.previous(@revisions)}
              aria-label="Previous revision"
              class="btn btn-square"
              disabled
              id="previous-revision"
              type="button"
            >
              <.icon name="hero-chevron-left-micro" class="size-4" />
            </button>
            <.link
              :if={Revisions.next(@revisions)}
              aria-label="Next revision"
              class="btn btn-square"
              id="next-revision"
              patch={~p"/wiki/#{@page.slug}/revisions/#{Revisions.next(@revisions).id}"}
            >
              <.icon name="hero-chevron-right-micro" class="size-4" />
            </.link>
            <button
              :if={!Revisions.next(@revisions)}
              aria-label="Next revision"
              class="btn btn-square"
              disabled
              id="next-revision"
              type="button"
            >
              <.icon name="hero-chevron-right-micro" class="size-4" />
            </button>
            <button
              aria-label="Restore revision"
              class="btn btn-info"
              disabled={@revisions.restoring?}
              phx-click="revisions:restore"
              type="button"
            >
              <span :if={@revisions.restoring?} class="loading loading-spinner loading-xs"></span>
              Restore
            </button>
          </div>
        </div>

        <div
          :if={@revisions.selected}
          class="lexical-playground"
          data-lexical-state={Jason.encode!(@revisions.selected.lexical_state)}
          data-pages={WikiLinkMap.encode(@wiki_link_map)}
          data-previous-lexical-state={Jason.encode!(Revisions.previous_lexical_state(@revisions))}
          id={"revision-preview-#{@revisions.selected.id}"}
          phx-hook="LexicalRevisionPreview"
          phx-update="ignore"
        >
        </div>

        <div :if={!@revisions.selected} class="hero min-h-64 rounded-box bg-base-200">
          <div class="hero-content text-center">
            <div>
              <h2 class="text-xl font-semibold">No revisions yet</h2>
              <p class="py-2 opacity-70">
                A revision will be created at the next document checkpoint.
              </p>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp requested_revision_id(%{assigns: %{live_action: :revisions, revisions: revisions}}) do
    revisions.requested_id
  end

  defp requested_revision_id(_socket), do: nil
end
