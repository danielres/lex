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
        |> assign(page_title_form: page_title_form(page.title))

      {:noreply, socket}
    else
      raise Ash.Error.Query.NotFound, resource: Page, primary_key: %{slug: slug}
    end
  end

  def handle_event("toggle_editable", _params, socket) do
    socket = update(socket, :editable, &(!&1))

    {:noreply, socket}
  end

  def handle_event("change_page_title", %{"page_title" => %{"title" => title}}, socket) do
    socket = assign(socket, :page_title_form, page_title_form(title))

    {:noreply, socket}
  end

  def handle_event("reset_page_title", _params, socket) do
    socket = assign(socket, :page_title_form, page_title_form(socket.assigns.page.title))

    {:noreply, socket}
  end

  def handle_event("rename_page", %{"page_title" => %{"title" => title}}, socket) do
    case Page.rename(socket.assigns.page, title) do
      {:ok, page} ->
        socket =
          socket
          |> assign(page: page)
          |> assign(pages: Page.list!())
          |> assign(page_title: page.title)
          |> assign(page_title_form: page_title_form(page.title))
          |> push_event("page_title_blur", %{})
          |> push_patch(to: ~p"/wiki/#{page.slug}")

        {:noreply, socket}

      {:error, error} ->
        errors = [title: {title_error(error), []}]

        socket =
          socket
          |> assign(page_title_form: page_title_form(title, errors))
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

        <.form
          :if={@editable && @page.slug != "home"}
          for={@page_title_form}
          id="page-title-form"
          phx-change="change_page_title"
          phx-hook=".PageTitleForm"
          phx-submit="rename_page"
          tabindex="-1"
          class="grow max-w-sm"
        >
          <div class={[
            "group join w-full rounded-box border border-base-100",
            "bg-base-200",
            "focus-within:border-info focus-within:bg-info/30"
          ]}>
            <input
              aria-label="Page title"
              autocomplete="off"
              class={[
                "peer join-item grow",
                "w-full rounded-l-box px-2",
                "text-2xl opacity-75",
                "outline-none"
              ]}
              id={@page_title_form[:title].id}
              name={@page_title_form[:title].name}
              phx-key="Escape"
              phx-keydown={reset_page_title()}
              phx-click-away={reset_page_title()}
              value={@page_title_form[:title].value}
            />
            <button
              aria-label="Cancel title change"
              class={[
                "hidden group-focus-within:block",
                "join-item btn btn-square btn-ghost",
                "bg-transparent"
              ]}
              phx-click={reset_page_title()}
              type="button"
            >
              <.icon name="hero-x-mark-micro" />
            </button>
            <button
              aria-label="Save page title"
              class={[
                "hidden group-focus-within:block",
                "join-item btn btn-square rounded-r-box",
                "btn-info"
              ]}
              type="submit"
            >
              <.icon name="hero-check-micro" />
            </button>
          </div>
          <p
            :for={{message, _options} <- @page_title_form[:title].errors}
            class="mt-1.5 flex items-center gap-2 text-sm text-error"
          >
            <.icon name="hero-exclamation-circle" class="size-5" />
            {message}
          </p>
        </.form>

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

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PageTitleForm">
        export default {
          mounted() {
            this.handleSubmit = () => this.el.querySelector("input")?.blur()
            this.el.addEventListener("submit", this.handleSubmit)
            this.handleEvent("page_title_blur", () => this.el.querySelector("input")?.blur())
          },

          destroyed() {
            this.el.removeEventListener("submit", this.handleSubmit)
          },
        }
      </script>

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

  defp page_title_form(title, errors \\ []) do
    to_form(%{"title" => title}, as: :page_title, errors: errors)
  end

  defp reset_page_title do
    JS.push("reset_page_title")
    |> JS.focus(to: "#page-title-form")
  end

  defp title_error(error) do
    error
    |> Ash.Error.to_error_class()
    |> Map.fetch!(:errors)
    |> Enum.find_value(Exception.message(error), fn
      %{field: :title, message: message} when is_binary(message) -> message
      _error -> nil
    end)
  end
end
