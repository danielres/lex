defmodule LexWeb.PageLive.Revisions.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:revisions]

  alias LexWeb.Router.Path
  alias LexWeb.Layouts

  def render(assigns) do
    ~H"""
    <Layouts.action_button
      title={(@active? && "Close") || "View versions"}
      icon="hero-clock-solid"
      active?={@active?}
      patch={(@active? && Path.to(@scope, @page)) || Path.revisions(@scope, @page)}
    />
    """
  end
end
