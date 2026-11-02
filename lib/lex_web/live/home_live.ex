defmodule LexWeb.HomeLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias LexWeb.UI

  delegate(:ui, UI)

  def mount(params, session, socket) do
    socket = delegate_mount(socket, params, session)

    spaces = [
      %{id: 1, slug: "space-1", name: "Space 1"},
      %{id: 2, slug: "space-2", name: "Space 2"},
      %{id: 3, slug: "space-3", name: "Space 3"},
      %{id: 4, slug: "space-4", name: "Space 4"},
      %{id: 5, slug: "space-5", name: "Space 5"}
    ]

    socket = socket |> assign(spaces: spaces)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class={[
      "min-h-svh",
      "flex items-center justify-center"
    ]}>
      <div class="max-w-md">
        <div class="flex flex-wrap gap-2">
          <.link
            :for={space <- @spaces}
            navigate={~p"/#{space.slug}"}
            class={[
              "p-4",
              "block",
              "size-32",
              "bg-base-100 rounded",
              "opacity-80 hover:opacity-100 transition"
            ]}
          >
            {space.name}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
