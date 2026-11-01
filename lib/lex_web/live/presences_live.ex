defmodule LexWeb.PresencesLive do
  use LexWeb, :live_view

  alias LexWeb.Components.Avatar

  @room_key "DEFAULT_TEMP_ROOM"

  @impl true
  def mount(_params, %{"collaborator" => collaborator}, socket) do
    socket = assign(socket, collaborator: collaborator, presences: get_presences())

    socket =
      if connected?(socket) do
        :ok = Group.monitor(:lex, @room_key)
        :ok = Group.join(:lex, @room_key, collaborator)

        assign(socket, :presences, get_presences())
      else
        socket
      end

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info({:group, _events, _info}, socket) do
    {:noreply, assign(socket, :presences, get_presences())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "opacity-0 pointer-events-none",
      "[[data-drawer-open=true]_&]:opacity-100",
      "[[data-drawer-open=true]_&]:pointer-events-auto",
      "transition",
      "space-y-2 pt-2 pb-4 px-4"
    ]}>
      <h3 class="flex items-baseline justify-between">
        <span class="small-caps tracking-wide">Online now</span>
        <span class="badge badge-xs" data-testid="presences-expanded-count">
          {length(@presences)}
        </span>
      </h3>

      <div class="flex flex-wrap gap-1 w-31" id="presences-list" phx-hook="AutoAnimate">
        <div
          :for={presence <- @presences}
          data-testid="presence"
          id={"presence-#{presence.display_name}"}
        >
          <Avatar.render user={presence} />
        </div>
      </div>
    </div>

    <div class={[
      "opacity-0 pointer-events-none",
      "[[data-drawer-open=false]_&]:opacity-100",
      "[[data-drawer-open=false]_&]:pointer-events-auto",
      "transition p-4"
    ]}>
      <button
        class="indicator"
        data-testid="presences-toggle"
        phx-click={JS.exec("phx-click", to: "#drawer-toggle")}
        type="button"
      >
        <span
          class={[
            "indicator-item",
            "badge badge-xs px-0.5",
            length(@presences) > 1 && "badge-accent",
            "font-semibold"
          ]}
          data-testid="presences-collapsed-count"
        >
          {length(@presences)}
        </span>
        <.icon name="hero-users-micro" class="opacity-50" />
      </button>
    </div>
    """
  end

  defp get_presences do
    :lex
    |> Group.members(@room_key)
    |> Enum.map(fn {_pid, presence} -> presence end)
    # |> Enum.uniq_by(& &1.display_name)
    |> Enum.sort_by(& &1.display_name)
  end
end
