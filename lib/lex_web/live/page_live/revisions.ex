defmodule LexWeb.PageLive.Revisions do
  use LexWeb, :live_view
  use LiveDelegate, path: [:revisions]

  alias Lex.Collaboration
  alias Lex.Wiki.Page
  alias LexWeb.Components.Avatar
  alias LexWeb.Components.Tooltip
  alias LexWeb.Router.Path

  def button_toggle(assigns), do: __MODULE__.ButtonToggle.render(assigns)

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{
      entries: [],
      requested_id: nil,
      restoring?: false,
      selected: nil,
      selected_index: nil
    })
  end

  def reload(socket, page, revision_id \\ nil) do
    scope = socket.assigns.scope
    entries = scope |> Page.list_revisions!(page)
    selected = select_revision!(entries, revision_id)
    selected_index = selected_index(entries, selected)

    socket
    |> delegate_assign(:entries, entries)
    |> delegate_assign(:requested_id, revision_id)
    |> delegate_assign(:selected, selected)
    |> delegate_assign(:selected_index, selected_index)
  end

  def commit_restore_event, do: delegate_event("commit_restore")
  def preserve_event, do: delegate_event("preserve")
  def restore_request_event, do: "revision_restore_requested"

  def previous(revisions) do
    if revisions.selected_index < length(revisions.entries) - 1 do
      Enum.at(revisions.entries, revisions.selected_index + 1)
    end
  end

  def next(revisions) do
    if revisions.selected_index > 0 do
      Enum.at(revisions.entries, revisions.selected_index - 1)
    end
  end

  def previous_lexical_state(revisions) do
    case previous(revisions) do
      nil -> nil
      revision -> revision.lexical_state
    end
  end

  def position(%{selected_index: nil}), do: nil
  def position(revisions), do: length(revisions.entries) - revisions.selected_index

  @impl true
  def handle_event("restore", _params, socket) do
    revision = socket.assigns.revisions.selected

    socket =
      socket
      |> delegate_assign(:restoring?, true)
      |> push_event(restore_request_event(), %{
        lexical_state: revision.lexical_state,
        revision_id: revision.id
      })

    {:noreply, socket}
  end

  def handle_event(
        "commit_restore",
        %{"documents" => documents, "revision_id" => revision_id},
        socket
      )
      when is_list(documents) do
    page = socket.assigns.page
    scope = socket.assigns.scope

    scope
    |> Collaboration.save(page, documents, revision_id)
    |> case do
      {:ok, _result} ->
        socket =
          socket
          |> delegate_assign(:restoring?, false)
          |> put_flash(:info, "Revision restored")
          |> push_patch(to: Path.to(scope, page))

        {:reply, %{ok: true}, socket}

      {:error, _reason} ->
        restore_failed(socket)
    end
  end

  def handle_event("commit_restore", _params, socket), do: restore_failed(socket)

  def handle_event("preserve", %{"documents" => documents}, socket)
      when is_list(documents) do
    scope = socket.assigns.scope
    page = socket.assigns.page

    scope
    |> Collaboration.save(page, documents)
    |> case do
      {:ok, _result} ->
        {:reply, %{ok: true}, socket}

      {:error, _reason} ->
        restore_failed(socket)
    end
  end

  def handle_event("preserve", _params, socket), do: restore_failed(socket)

  defp restore_failed(socket) do
    socket =
      socket
      |> delegate_assign(:restoring?, false)
      |> put_flash(:error, "Could not restore the revision")

    {:reply, %{ok: false}, socket}
  end

  defp select_revision!([], nil), do: nil
  defp select_revision!([revision | _revisions], nil), do: revision

  defp select_revision!(revisions, revision_id) do
    Enum.find(revisions, &(&1.id == revision_id)) ||
      raise Ash.Error.Query.NotFound,
        resource: Lex.Wiki.PageRevision,
        primary_key: %{id: revision_id}
  end

  defp selected_index(_entries, nil), do: nil
  defp selected_index(entries, selected), do: Enum.find_index(entries, &(&1.id == selected.id))

  def render_dialog(assigns) do
    ~H"""
    <div :if={@revisions.selected}>
      <h2 class="small-caps text-lg inline">Version</h2>

      <span class="ml-2">
        <span class="font-bold">{position(@revisions)}</span>
        <span class="font-bold text-base-content/75">/</span>
        <span class="text-sm">{length(@revisions.entries)}</span>
      </span>

      <span class="mx-1 text-base-content/75">-</span>

      <span class="text-sm text-base-content/75">
        {Utils.Time.relative(@revisions.selected.inserted_at)}
      </span>
    </div>

    <div :if={is_nil(@revisions.selected)}>
      No versions yet
    </div>

    <div
      :if={@revisions.selected}
      class={[
        "flex items-end justify-between gap-3"
      ]}
    >
      <div class="grid grow gap-0">
        <div
          :if={@revisions.selected.contributors != []}
          class="flex items-center gap-3"
          data-testid="revision-contributors"
        >
          <div class="flex flex-wrap gap-2">
            <Tooltip.render
              :for={contributor <- @revisions.selected.contributors}
              alignment="start"
            >
              <Avatar.render user={contributor} />
              <:tooltip>{contributor.display_name}</:tooltip>
            </Tooltip.render>
          </div>
        </div>
      </div>

      <div class="flex gap-1">
        <.link
          :if={previous(@revisions)}
          aria-label="Previous revision"
          class="btn btn-square hover:btn-info"
          id="previous-revision"
          patch={Path.to(@scope, @page, previous(@revisions))}
        >
          <.icon name="hero-chevron-left-micro" class="size-4" />
        </.link>
        <button
          :if={!previous(@revisions)}
          aria-label="Previous revision"
          class="btn btn-square hover:btn-info"
          disabled
          id="previous-revision"
          type="button"
        >
          <.icon name="hero-chevron-left-micro" class="size-4" />
        </button>
        <.link
          :if={next(@revisions)}
          aria-label="Next revision"
          class="btn btn-square hover:btn-info"
          id="next-revision"
          patch={Path.to(@scope, @page, next(@revisions))}
        >
          <.icon name="hero-chevron-right-micro" class="size-4" />
        </.link>
        <button
          :if={!next(@revisions)}
          aria-label="Next revision"
          class="btn btn-square hover:btn-info"
          disabled
          id="next-revision"
          type="button"
        >
          <.icon name="hero-chevron-right-micro" class="size-4" />
        </button>
        <button
          :if={can?(@scope, :edit_pages)}
          aria-label="Restore revision"
          class="btn btn-info rounded"
          disabled={@revisions.restoring?}
          phx-click="revisions:restore"
          type="button"
        >
          <span :if={@revisions.restoring?} class="loading loading-spinner loading-xs"></span> Restore
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <% user = @scope.user %>

    <div
      :if={@revisions.selected}
      class="lexical-editor"
      data-collaborator-display-name={user.display_name}
      data-collaborator-hue={user.hue}
      data-save-page-event={assigns[:"data-save-page-event"]}
      data-lexical-state={Jason.encode!(@revisions.selected.lexical_state)}
      data-load-page-content-event={assigns[:"data-load-page-content-event"]}
      data-page-id={assigns[:"data-page-id"]}
      data-pages={assigns[:"data-pages"]}
      data-previous-lexical-state={Jason.encode!(previous_lexical_state(@revisions))}
      data-resolve-page-event={assigns[:"data-resolve-page-event"]}
      data-space-id={assigns[:"data-space-id"]}
      id={"revision-preview-#{@revisions.selected.id}"}
      phx-hook="LexicalRevisionPreview"
      phx-update="ignore"
    >
    </div>
    """
  end
end
