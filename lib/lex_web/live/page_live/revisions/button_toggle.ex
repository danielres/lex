defmodule LexWeb.PageLive.Revisions.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:revisions]

  alias LexWeb.Router.Path

  def render(assigns) do
    ~H"""
    <.link
      :if={!@active?}
      aria-label="Page versions"
      class="btn btn-xs btn-circle btn-neutral hover:btn-info"
      patch={Path.revisions(@scope, @page)}
      title="Page versions"
    >
      <.icon name="hero-clock-solid" />
    </.link>

    <.link
      :if={@active?}
      aria-label="Close"
      class="btn btn-xs btn-circle btn-info"
      patch={Path.to(@scope, @page)}
      title="Close"
    >
      <.icon name="hero-clock-solid" />
    </.link>
    """
  end
end
