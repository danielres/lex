defmodule LexWeb.PageLive.Revisions.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:revisions]

  def render(assigns) do
    ~H"""
    <.link
      :if={!@active?}
      aria-label="Browse revisions"
      class="btn btn-square rounded-box"
      patch={~p"/#{@space.slug}/wiki/#{@page.slug}/revisions"}
      title="Browse revisions"
    >
      <.icon name="hero-clock-solid" />
    </.link>

    <.link
      :if={@active?}
      aria-label="Return to current page"
      class="btn btn-square rounded-box btn-info"
      patch={~p"/#{@space.slug}/wiki/#{@page.slug}"}
      title="Return to current page"
    >
      <.icon name="hero-clock-solid" />
    </.link>
    """
  end
end
