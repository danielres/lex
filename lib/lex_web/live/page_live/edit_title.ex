defmodule LexWeb.PageLive.EditTitle do
  use LexWeb, :live_view
  use LiveDelegate, path: [:edit_title]

  alias LexWeb.Components.ResourceRename

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{form: nil})
  end

  def reload(socket, page) do
    scope = socket.assigns.scope

    form =
      if can?(scope, :edit_pages) do
        scope |> title_form(page)
      end

    socket |> delegate_assign(:form, form)
  end

  @impl true
  def handle_event("open", _params, socket) do
    page = socket.assigns.page

    socket =
      socket
      |> reload(page)
      |> assign(live_action: :edit_title)

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    socket = socket |> assign(live_action: :info)

    {:noreply, socket}
  end

  def handle_event(event, _params, %{assigns: %{edit_title: %{form: nil}}} = socket)
      when event in ["change", "save"] do
    {:noreply, socket}
  end

  def handle_event("change", %{"page_title" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.edit_title.form, params)
    socket = socket |> delegate_assign(:form, form)

    {:noreply, socket}
  end

  def handle_event("save", %{"page_title" => params}, socket) do
    socket.assigns.edit_title.form
    |> AshPhoenix.Form.submit(params: params)
    |> case do
      {:ok, page} ->
        {:noreply, Toast.put_toast(socket, :info, ~s(Renamed page to "#{page.title}"))}

      {:error, form} ->
        socket =
          socket
          |> delegate_assign(:form, form)
          |> push_event("page_title_blur", %{})

        {:noreply, socket}
    end
  end

  def button_edit(assigns) do
    ~H"""
    <ResourceRename.button_edit event={delegate_event("open")} data-testid="edit-title-button" />
    """
  end

  attr :edit_title, :map, required: true

  def render_form(assigns) do
    ~H"""
    <ResourceRename.render_form
      id="page-title-form"
      form={@edit_title.form}
      field={@edit_title.form[:title]}
      label="Page title"
      path_prefix="/wiki/"
      change_event={delegate_event("change")}
      save_event={delegate_event("save")}
      cancel_event={delegate_event("cancel")}
      data-testid="edit-title-form"
      cancel_testid="edit-title-cancel"
    />
    """
  end

  defp title_form(scope, page) do
    page
    |> AshPhoenix.Form.for_update(:rename, as: "page_title", scope: scope)
    |> to_form()
  end
end
