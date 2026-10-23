defmodule LexWeb.WikiLive do
  use LexWeb, :live_view

  alias Lex.Wiki.Page

  def mount(_params, _session, socket) do
    if connected?(socket), do: Page.subscribe()

    socket = assign(socket, :pages, list_pages())

    {:ok, socket}
  end

  def handle_info(%Ash.Notifier.Notification{action: %{name: :rename_page}}, socket) do
    socket = assign(socket, :pages, list_pages())

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active="wiki">
      <ul class="list list-disc pl-4">
        <li><.link class="link link-hover link-info" navigate={~p"/wiki/home"}>Home</.link></li>
        <li :for={page <- @pages}>
          <.link class="link link-hover link-info" navigate={~p"/wiki/#{page.slug}"}>
            {page.title}
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  defp list_pages do
    Page.list!() |> Enum.reject(&(&1.slug == "home"))
  end
end
