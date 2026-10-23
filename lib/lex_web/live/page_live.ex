defmodule LexWeb.PageLive do
  use LexWeb, :live_view

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageSlug

  def mount(_params, _session, socket) do
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

      {:noreply, socket}
    else
      raise Ash.Error.Query.NotFound, resource: Page, primary_key: %{slug: slug}
    end
  end

  def handle_event("toggle_editable", _params, socket) do
    socket = update(socket, :editable, &(!&1))

    {:noreply, socket}
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

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active="page">
      <div class="flex justify-between pt-6 gap-4 pb-2">
        <h1
          :if={!@editable || @page.slug == "home"}
          class={[
            "text-3xl opacity-75 grow",
            "self-end",
            "leading-tight"
          ]}
        >
          {@page_title}
        </h1>

        <div
          :if={@editable && @page.slug != "home"}
          class={[
            "grow join max-w-sm border border-base-100 focus-within:border-info rounded-box",
            "bg-base-200",
            "focus:bg-info/30 dark:focus:bg-info/30"
          ]}
        >
          <input
            value={@page_title}
            class={[
              "peer",
              "join-item",
              "text-2xl opacity-75 grow",
              "rounded-l-box w-full px-2",
              "outline-none"
            ]}
          />
          <button
            class={[
              "hidden peer-focus:block",
              "join-item",
              "btn btn-square btn-ghost",
              "bg-transparent"
            ]}
            type="button"
          >
            <.icon name="hero-x-mark-micro" />
          </button>
          <button
            class={[
              "hidden peer-focus:block",
              "join-item",
              "btn btn-square rounded-r-box",
              "btn-info"
            ]}
            type="button"
          >
            <.icon name="hero-check-micro" />
          </button>
        </div>

        <button
          aria-label={if @editable, do: "Make editor read-only", else: "Enable editing"}
          aria-pressed={!@editable}
          class={[
            "btn btn-square rounded-box",
            @editable && "btn-info"
          ]}
          phx-click="toggle_editable"
          title={if @editable, do: "Make editor read-only", else: "Enable editing"}
          type="button"
        >
          <.icon
            name={if @editable, do: "hero-lock-open-solid", else: "hero-lock-closed-solid"}
            class="size-4"
          />
        </button>
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
end
