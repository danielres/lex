defmodule LexWeb.WikiLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Ash.Notifier.Notification
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias LexWeb.Space
  alias LexWeb.UI

  delegate(:space, Space)
  delegate(:ui, UI)

  @sort_fields %{
    "inserted_at" => :inserted_at,
    "last_updated_at" => :last_updated_at,
    "title" => :title
  }

  def mount(params, session, socket) do
    if connected?(socket), do: Page.subscribe()

    socket = socket |> delegate_mount(params, session)
    scope = socket.assigns.scope

    tz =
      case get_connect_params(socket) do
        %{"tz" => timezone} -> timezone
        _ -> "Etc/UTC"
      end

    pages = scope |> list_pages(:last_updated_at, :desc)

    socket =
      socket
      |> assign(pages: pages)
      |> assign(sort_by: :last_updated_at)
      |> assign(sort_direction: :desc)
      |> assign(tz: tz)

    {:ok, socket}
  end

  def handle_info(%Notification{resource: Page, action: %{name: action}}, socket)
      when action in [:create, :rename] do
    sort_by = socket.assigns.sort_by
    sort_direction = socket.assigns.sort_direction
    scope = socket.assigns.scope
    pages = scope |> list_pages(sort_by, sort_direction)

    socket = socket |> assign(pages: pages)

    {:noreply, socket}
  end

  def handle_info(%Notification{resource: PageDocument, action: %{name: action}}, socket)
      when action in [:save, :save_snapshot] do
    sort_by = socket.assigns.sort_by
    sort_direction = socket.assigns.sort_direction
    scope = socket.assigns.scope
    pages = scope |> list_pages(sort_by, sort_direction)

    socket = socket |> assign(pages: pages)

    {:noreply, socket}
  end

  def handle_event("sort", %{"sort-by" => sort_by_param}, socket) do
    sort_by = Map.fetch!(@sort_fields, sort_by_param)
    sort_direction = next_sort_direction(socket.assigns, sort_by)
    scope = socket.assigns.scope
    pages = scope |> list_pages(sort_by, sort_direction)

    socket =
      socket
      |> assign(:pages, pages)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_direction, sort_direction)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      active="wiki"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      space={@space}
      ui={@ui}
    >
      <div class="space-y-4 max-w-[80ch]">
        <div class="flex justify-end">
          <.link
            navigate={~p"/#{@space.slug}/wiki/home"}
            class="btn btn-info px-2 rounded-box"
          >
            <.icon name="hero-home-micro" />
            <span>Home</span>
            <.icon name="hero-chevron-right-micro" />
          </.link>
        </div>

        <div class="bg-base-300 p-0 rounded-box">
          <table class="table max-sm:table-sm">
            <thead>
              <tr>
                <th aria-sort={aria_sort(@sort_by, @sort_direction, :title)} class="w-1/3">
                  <.sortable
                    field={:title}
                    sort_by={@sort_by}
                    sort_direction={@sort_direction}
                  >
                    Page
                  </.sortable>
                </th>
                <th aria-sort={aria_sort(@sort_by, @sort_direction, :inserted_at)} class="w-1/3">
                  <.sortable
                    field={:inserted_at}
                    sort_by={@sort_by}
                    sort_direction={@sort_direction}
                  >
                    Created
                  </.sortable>
                </th>
                <th aria-sort={aria_sort(@sort_by, @sort_direction, :last_updated_at)}>
                  <.sortable
                    field={:last_updated_at}
                    sort_by={@sort_by}
                    sort_direction={@sort_direction}
                  >
                    Updated
                  </.sortable>
                </th>
              </tr>
            </thead>

            <tbody phx-hook="AutoAnimate" id="wiki-pages-entries">
              <tr :for={page <- @pages} id={"wiki-pages-entries-" <> page.id}>
                <td>
                  <.link
                    class={[
                      "font-semibold",
                      "flex items-center gap-1",
                      page.slug != "home" && "text-base-content/75",
                      page.slug == "home" && "text-base-content",
                      "hover:text-info",
                      "transition"
                    ]}
                    navigate={~p"/#{@space.slug}/wiki/#{page.slug}"}
                  >
                    {page.title}
                    <.icon :if={page.slug == "home"} name="hero-home-mini" class="opacity-50" />
                  </.link>
                </td>
                <td>
                  {Utils.Time.relative(page.inserted_at)}
                </td>
                <td>
                  {Utils.Time.relative(page.last_updated_at)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :field, :atom, required: true
  attr :sort_by, :atom, required: true
  attr :sort_direction, :atom, required: true
  slot :inner_block, required: true

  defp sortable(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "flex w-full cursor-pointer items-center gap-2 text-left",
        "hover:text-info transition"
      ]}
      phx-click="sort"
      phx-value-sort-by={@field}
    >
      <span>{render_slot(@inner_block)}</span>
      <.icon
        :if={@sort_by == @field && @sort_direction == :asc}
        name="hero-chevron-up-micro"
      />
      <.icon
        :if={@sort_by == @field && @sort_direction == :desc}
        name="hero-chevron-down-micro"
      />
      <.icon
        :if={@sort_by != @field}
        class="opacity-40"
        name="hero-chevron-up-down-micro"
      />
    </button>
    """
  end

  defp aria_sort(sort_by, sort_direction, field) do
    if sort_by == field do
      Atom.to_string(sort_direction) <> "ending"
    else
      "none"
    end
  end

  defp list_pages(scope, sort_by, sort_direction) do
    Page.list!(query: [sort: [{sort_by, sort_direction}]], scope: scope)
  end

  defp next_sort_direction(%{sort_by: sort_by, sort_direction: :asc}, sort_by), do: :desc
  defp next_sort_direction(%{sort_by: sort_by, sort_direction: :desc}, sort_by), do: :asc
  defp next_sort_direction(_assigns, :title), do: :asc

  defp next_sort_direction(_assigns, field)
       when field in [:inserted_at, :last_updated_at],
       do: :desc
end
