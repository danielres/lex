defmodule LexWeb.PageController do
  use LexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def index conn, _params do
    conn |> put_root_layout(html: {LexWeb.Layouts, :spa_root}) |> render(:index)
  end
end
