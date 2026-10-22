defmodule LexWeb.WikiLive do
  use LexWeb, :live_view

  alias Lex.Wiki.Page

  def mount(_params, _session, socket) do
    pages = Page.list!() |> Enum.reject(&(&1.slug == "home"))
    socket = assign(socket, pages: pages)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app content_class="mx-auto max-w-7xl" flash={@flash}>
      <ul class="list list-disc pl-4">
        <li><.link class="link link-hover link-info" navigate={~p"/wiki/home"}>Home</.link></li>
        <li :for={page <- @pages}>
          <.link class="link link-hover link-info" navigate={~p"/wiki/#{page.slug}"}>{page.slug}</.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
