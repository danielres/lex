defmodule LexWeb.PageLive do
  use LexWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app content_class="mx-auto max-w-7xl" flash={@flash}>
      <div
        class="lexical-playground"
        data-document-id="playground"
        id="lexical-editor"
        phx-hook="LexicalEditor"
        phx-update="ignore"
      >
      </div>
    </Layouts.app>
    """
  end
end
