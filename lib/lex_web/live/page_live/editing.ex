defmodule LexWeb.PageLive.Editing do
  use LexWeb, :live_view
  use LiveDelegate, path: [:editing]

  require Logger

  alias Lex.Collaboration

  def button_toggle(assigns), do: __MODULE__.ButtonToggle.render(assigns)

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{saving?: false, title_form: nil})
  end

  def reload(socket, page) do
    scope = socket.assigns.scope

    form =
      if can?(scope, :edit_pages) do
        scope |> title_form(page)
      end

    socket |> delegate_assign(:title_form, form)
  end

  def save_event, do: delegate_event("save")
  def save_request_event, do: "page_save_requested"

  @impl true
  def handle_event("toggle", _params, socket) do
    editing = socket.assigns.editing

    socket =
      cond do
        editing.saving? ->
          socket

        socket.assigns.live_action == :editing ->
          socket
          |> delegate_assign(:saving?, true)
          |> push_event(save_request_event(), %{})

        true ->
          assign(socket, :live_action, :editing)
      end

    {:noreply, socket}
  end

  def handle_event("save", %{"documents" => documents}, socket)
      when is_list(documents) do
    scope = socket.assigns.scope
    page = socket.assigns.page

    scope
    |> Collaboration.save(page, documents)
    |> case do
      {:ok, counts} ->
        socket =
          socket
          |> delegate_assign(:saving?, false)
          |> assign(:live_action, :show)
          |> push_patch(
            replace: true,
            to: ~p"/#{socket.assigns.scope.space.slug}/wiki/#{socket.assigns.page.slug}"
          )

        {:reply, %{ok: true, result: counts}, socket}

      {:error, reason} ->
        Logger.error("Could not save page #{page.id}: #{inspect(reason)}")
        save_failed(socket)
    end
  end

  def handle_event("save", %{"error" => reason}, socket) do
    Logger.error(
      "Could not collect document snapshots for page #{socket.assigns.page.id}: #{inspect(reason)}"
    )

    save_failed(socket)
  end

  def handle_event("save", params, socket) do
    Logger.error(
      "Received invalid page save payload for page #{socket.assigns.page.id}: #{inspect(params)}"
    )

    save_failed(socket)
  end

  def handle_event("title_change", %{"page_title" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.editing.title_form, params)
    socket = socket |> delegate_assign(:title_form, form)

    {:noreply, socket}
  end

  def handle_event("title_reset", _params, socket) do
    socket = reload(socket, socket.assigns.page)

    {:noreply, socket}
  end

  def handle_event("title_save", %{"page_title" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.editing.title_form, params: params) do
      {:ok, _page} ->
        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> delegate_assign(:title_form, form)
          |> push_event("page_title_blur", %{})

        {:noreply, socket}
    end
  end

  defp title_form(scope, page) do
    page
    |> AshPhoenix.Form.for_update(:rename, as: "page_title", scope: scope)
    |> to_form()
  end

  defp save_failed(socket) do
    socket =
      socket
      |> delegate_assign(:saving?, false)
      |> put_flash(:error, "Could not save the document")

    {:reply, %{ok: false}, socket}
  end
end
