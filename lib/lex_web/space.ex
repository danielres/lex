defmodule LexWeb.Space do
  use LexWeb, :live_view
  use LiveDelegate, path: [:space]

  def on_mount(params, _session, socket) do
    slug = params["space_slug"]
    delegate_assign(socket, %{slug: slug})
  end
end
