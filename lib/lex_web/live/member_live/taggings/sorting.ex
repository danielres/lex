defmodule LexWeb.MemberLive.Taggings.Sorting do
  use LexWeb, :live_view
  use LiveDelegate, path: [:taggings, :sorting]

  alias Lex.Topics.Dimensions
  alias Lex.Topics.Tagging

  @default_sorting %{by: :alpha, direction: :asc}
  @local_settings_changed_event "local-settings-changed"

  def on_mount(_params, _session, socket) do
    user_id = socket.assigns.scope.user.id
    sorting = local_sorting(get_connect_params(socket), user_id)

    delegate_assign(socket, sorting)
  end

  @impl true
  def handle_event("start", _params, socket) do
    {:noreply, assign(socket, :mode, :sort_taggings)}
  end

  def handle_event("sort", %{"by" => by}, socket) do
    current_sorting = socket.assigns.taggings.sorting
    by = String.to_existing_atom(by)

    direction =
      if current_sorting.by == by do
        reverse(current_sorting.direction)
      else
        default_direction(by)
      end

    sorting = %{by: by, direction: direction}
    profile = socket.assigns.profile
    scope = socket.assigns.scope
    {:ok, groups} = Tagging.present_for_target(profile, sorting, scope: scope)

    socket =
      socket
      |> delegate_assign(sorting)
      |> update(:taggings, &Map.put(&1, :groups, groups))
      |> push_event(@local_settings_changed_event, local_settings(scope.user.id, sorting))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h3 class="small-caps">Sort by</h3>

    <ul class="grid gap-2">
      <li>
        <.sorting_button
          phx-click={delegate_event("sort")}
          phx-value-by="alpha"
        >
          <.direction value={direction(@sorting, :alpha)} />

          <div class={[
            "size-4 rounded-full",
            "flex items-center justify-center",
            "text-xs font-semibold"
          ]}>
            Aa
          </div>
          <span class="text-sm opacity-80">Topic name</span>
        </.sorting_button>
      </li>

      <li>
        <.sorting_button
          phx-click={delegate_event("sort")}
          phx-value-by="experience"
        >
          <.direction value={direction(@sorting, :experience)} />
          <.dimension dimension="experience" />
          <span class="text-sm opacity-80">Experience</span>
        </.sorting_button>
      </li>

      <li>
        <.sorting_button
          phx-click={delegate_event("sort")}
          phx-value-by="interest"
        >
          <.direction value={direction(@sorting, :interest)} />
          <.dimension dimension="interest" />
          <span class="text-sm opacity-80">Interest</span>
        </.sorting_button>
      </li>
    </ul>
    """
  end

  attr :rest, :global
  slot :inner_block, required: true

  defp sorting_button(assigns) do
    ~H"""
    <button
      type="button"
      class="flex gap-2 items-center cursor-pointer clickable"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :value, :atom

  defp direction(assigns) do
    ~H"""
    <span class="size-4 flex items-center justify-center">
      <.icon :if={@value == :asc} name="hero-chevron-down-micro" />
      <.icon :if={@value == :desc} name="hero-chevron-up-micro" />
    </span>
    """
  end

  defp dimension(assigns) do
    ~H"""
    <div
      class="mx-0.5 size-3 rounded-full"
      style={"background: #{Dimensions.get!("membership", @dimension).color}"}
    />
    """
  end

  defp default_direction(:alpha), do: :asc
  defp default_direction(_dimension), do: :desc

  defp reverse(:asc), do: :desc
  defp reverse(:desc), do: :asc

  defp direction(%{by: by, direction: direction}, by), do: direction
  defp direction(_sorting, _by), do: nil

  defp local_sorting(params, user_id) do
    sorting =
      get_in(params || %{}, [
        "local_settings",
        "users",
        user_id,
        "member_taggings",
        "sorting"
      ])

    case sorting do
      %{"by" => by, "direction" => direction}
      when by in ["alpha", "experience", "interest"] and direction in ["asc", "desc"] ->
        %{
          by: String.to_existing_atom(by),
          direction: String.to_existing_atom(direction)
        }

      _other ->
        @default_sorting
    end
  end

  defp local_settings(user_id, sorting) do
    %{
      users: %{
        user_id => %{
          member_taggings: %{
            sorting: %{
              by: Atom.to_string(sorting.by),
              direction: Atom.to_string(sorting.direction)
            }
          }
        }
      }
    }
  end
end
