defmodule LexWeb.PageLive.Revisions.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:revisions]

  alias LexWeb.Router.Path

  def render(assigns) do
    ~H"""
    <.link
      :if={!@active?}
      aria-label="Browse revisions"
      class="btn btn-sm btn-circle btn-neutral hover:btn-info"
      patch={Path.revisions(@scope, @page)}
      title="Browse revisions"
    >
      <.icon name="hero-clock-solid" />
    </.link>

    <.link
      :if={@active?}
      aria-label="Return to current page"
      class="btn btn-sm btn-circle btn-info"
      patch={Path.to(@scope, @page)}
      title="Return to current page"
    >
      <.icon name="hero-clock-solid" />
    </.link>
    """
  end
end
