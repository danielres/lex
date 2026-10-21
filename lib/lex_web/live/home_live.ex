defmodule LexWeb.HomeLive do
  use LexWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      Hello
    </Layouts.app>
    """
  end
end
