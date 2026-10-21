defmodule LexWeb.PageLive do
  use LexWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"page_slug" => slug}, _uri, socket) do
    if Lex.Wiki.PageSlug.valid?(slug) do
      page = Lex.Wiki.ensure_page!(slug)

      socket =
        socket
        |> assign(page: page)
        |> assign(page_title: title_from_slug(slug))

      {:noreply, socket}
    else
      raise Ash.Error.Query.NotFound, resource: Lex.Wiki.Page, primary_key: %{slug: slug}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app content_class="mx-auto max-w-7xl" flash={@flash}>
      <div
        class="lexical-playground"
        data-document-id={@page.id}
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
