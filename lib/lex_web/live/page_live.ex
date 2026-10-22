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
      page = Page.ensure!(slug)

      socket =
        socket
        |> assign(page: page)
        |> assign(page_title: title_from_slug(slug))

      {:noreply, socket}
    else
      raise Ash.Error.Query.NotFound, resource: Page, primary_key: %{slug: slug}
    end
  end

  def handle_event("toggle_editable", _params, socket) do
    socket = update(socket, :editable, &(!&1))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active="page">
      <div class="flex justify-end pb-2">
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
            class={[
              "size-4"
            ]}
          />
        </button>
      </div>

      <div
        class="lexical-playground"
        data-document-id={@page.id}
        data-editable={to_string(@editable)}
        id={"lexical-editor-#{@page.id}"}
        phx-hook="LexicalEditor"
        phx-update="ignore"
      >
      </div>
    </Layouts.app>
    """
  end

  defp title_from_slug(slug) do
    slug
    |> String.split("-")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
