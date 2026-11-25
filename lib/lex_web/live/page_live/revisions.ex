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
      latest_number: nil,
      previous_lexical_state: nil,
      requested_number: nil,
      restoring?: false,
      selected: nil,
      selected_number: nil
    })
  end

  def reload(socket, page, requested_number \\ nil) do
    scope = socket.assigns.scope
    requested_number = parse_number!(requested_number)
    selection = scope |> Page.revision_selection!(page, requested_number)

    socket
    |> delegate_assign(:latest_number, selection.latest_number)
    |> delegate_assign(:previous_lexical_state, selection.previous_lexical_state)
    |> delegate_assign(:requested_number, requested_number)
    |> delegate_assign(:selected, selection.selected)
    |> delegate_assign(:selected_number, selection.selected_number)
  end

  def commit_restore_event, do: delegate_event("commit_restore")
  def preserve_event, do: delegate_event("preserve")
  def restore_request_event, do: "revision_restore_requested"

  def previous_number(%{selected_number: number}) when is_integer(number) and number > 1,
    do: number - 1

  def previous_number(_revisions), do: nil

  def next_number(%{latest_number: latest, selected_number: number})
      when is_integer(latest) and is_integer(number) and number < latest,
      do: number + 1

  def next_number(_revisions), do: nil

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

  defp parse_number!(nil), do: nil
  defp parse_number!(value) when is_integer(value) and value > 0, do: value

  defp parse_number!(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _other -> revision_not_found!(value)
    end
  end

  defp revision_not_found!(revision_number) do
    raise Ash.Error.Query.NotFound,
      resource: Lex.Wiki.PageRevision,
      primary_key: %{number: revision_number}
  end

  def render_dialog(assigns) do
    ~H"""
    <div :if={@revisions.selected}>
      <h2 class="small-caps text-lg inline">Version</h2>

      <span class="ml-2">
        <span class="font-bold">{@revisions.selected_number}</span>
        <span class="font-bold text-base-content/75">/</span>
        <span class="text-sm">{@revisions.latest_number}</span>
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
          :if={previous_number(@revisions)}
          aria-label="Previous revision"
          class="btn btn-square hover:btn-info"
          id="previous-revision"
          patch={Path.to(@scope, @page, previous_number(@revisions))}
        >
          <.icon name="hero-chevron-left-micro" class="size-4" />
        </.link>
        <button
          :if={!previous_number(@revisions)}
          aria-label="Previous revision"
          class="btn btn-square hover:btn-info"
          disabled
          id="previous-revision"
          type="button"
        >
          <.icon name="hero-chevron-left-micro" class="size-4" />
        </button>
        <.link
          :if={next_number(@revisions)}
          aria-label="Next revision"
          class="btn btn-square hover:btn-info"
          id="next-revision"
          patch={Path.to(@scope, @page, next_number(@revisions))}
        >
          <.icon name="hero-chevron-right-micro" class="size-4" />
        </.link>
        <button
          :if={!next_number(@revisions)}
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
      data-previous-lexical-state={Jason.encode!(@revisions.previous_lexical_state)}
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
