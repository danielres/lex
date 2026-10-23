defmodule LexWeb.PageLive do
  use LexWeb, :live_view

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageSlug
  alias LexWeb.PageLive.EditableTitle
  alias LexWeb.PageLive.ButtonToggleEdit

  def mount(_params, _session, socket) do
    if connected?(socket), do: Page.subscribe()
    socket = assign(socket, :editable, false)
    {:ok, socket}
  end

  def handle_params(%{"page_slug" => slug}, _uri, socket) do
    if PageSlug.valid?(slug) do
      page = Page.open!(slug)
      pages = Page.list!()

      socket =
        socket
        |> assign(page: page)
        |> assign(pages: pages)
        |> assign(page_title: page.title)
        |> assign(page_title_form: page_title_form(page))

      {:noreply, socket}
    else
      raise Ash.Error.Query.NotFound, resource: Page, primary_key: %{slug: slug}
    end
  end

  def handle_event("toggle_editable", _params, socket) do
    socket = update(socket, :editable, &(!&1))
    {:noreply, socket}
  end

  def handle_event("change_page_title", %{"page_title" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.page_title_form, params)
    socket = assign(socket, :page_title_form, form)

    {:noreply, socket}
  end

  def handle_event("reset_page_title", _params, socket) do
    socket = assign(socket, :page_title_form, page_title_form(socket.assigns.page))

    {:noreply, socket}
  end

  def handle_event("rename_page", %{"page_title" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.page_title_form, params: params) do
      {:ok, _page} ->
        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> assign(page_title_form: form)
          |> push_event("page_title_blur", %{})

        {:noreply, socket}
    end
  end

  def handle_event("ensure_wiki_page", %{"title" => title}, socket) do
    case Page.ensure(title) do
      {:ok, page} -> {:reply, %{ok: true, page: page_reference(page)}, socket}
      {:error, error} -> {:reply, %{ok: false, error: Exception.message(error)}, socket}
    end
  end

  def handle_event("resolve_wiki_page", %{"id" => id}, socket) do
    case Page.get(id) do
      {:ok, page} -> {:reply, %{ok: true, page: page_reference(page)}, socket}
      {:error, _error} -> {:reply, %{ok: false}, socket}
    end
  end

  def handle_info(
        %Ash.Notifier.Notification{action: %{name: :create_page}},
        socket
      ) do
    socket = assign(socket, :pages, Page.list!())

    {:noreply, socket}
  end

  def handle_info(
        %Ash.Notifier.Notification{action: %{name: :rename_page}, data: renamed_page},
        socket
      ) do
    pages = Page.list!()
    current_page = socket.assigns.page

    socket = assign(socket, :pages, pages)

    if current_page.id == renamed_page.id do
      socket =
        socket
        |> assign(page: renamed_page)
        |> assign(page_title: renamed_page.title)
        |> assign(page_title_form: page_title_form(renamed_page))
        |> push_event("page_title_blur", %{})
        |> push_patch(to: ~p"/wiki/#{renamed_page.slug}")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active="page">
      <div class="flex justify-between pt-6 gap-4 pb-2">
        <EditableTitle.render {assigns} />
        <ButtonToggleEdit.render {assigns} />
      </div>

      <div
        class="lexical-playground"
        data-document-id={@page.id}
        data-editable={to_string(@editable)}
        data-pages={Jason.encode!(Enum.map(@pages, &page_reference/1))}
        id={"lexical-editor-#{@page.id}"}
        phx-hook="LexicalEditor"
        phx-update="ignore"
      >
      </div>
    </Layouts.app>
    """
  end

  defp page_reference(page) do
    %{
      id: page.id,
      path: ~p"/wiki/#{page.slug}",
      slug: page.slug,
      title: page.title
    }
  end

  defp page_title_form(page) do
    page
    |> AshPhoenix.Form.for_update(:rename_page, as: "page_title")
    |> to_form()
  end
end
