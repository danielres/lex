defmodule LexWeb.MemberLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Accounts.Membership
  alias Lex.Topics.Tagging
  alias LexWeb.Layouts
  alias LexWeb.MemberLive.Taggings
  alias LexWeb.Router.Path
  alias LexWeb.UI

  require Ash.Query

  delegate(:taggings, Taggings)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    scope = socket.assigns.scope
    slug = params["member_slug"]
    result = find_profile(scope, slug)

    case result do
      {:ok, profile} ->
        socket =
          socket
          |> assign(:mode, :view)
          |> assign(:profile, profile)
          |> delegate_mount(params, session)

        {:ok, socket}

      {:error, _error} ->
        {:ok,
         socket
         |> assign(:profile, nil)
         |> Toast.put_toast(:error, "Member not found")
         |> push_navigate(to: ~p"/#{scope.space.slug}")}
    end
  end

  @impl true
  def handle_info(%{resource: Tagging} = message, socket) do
    Taggings.handle_info(message, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="members"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <div
        phx-click-away={if @mode != :view, do: "taggings:mode:reset"}
        phx-key="escape"
        phx-window-keydown={if @mode != :view, do: "taggings:mode:reset"}
      >
        <Layouts.page_head dialog?={@mode != :view}>
          <:title>
            <.link navigate={Path.members(@scope)} class="opacity-80 hover:opacity-100 transition">Members</.link>
          </:title>
          <:title><span>{@profile.display_name}</span></:title>
          <:actions><Taggings.render_actions mode={@mode} /></:actions>
          <:dialog>
            <Taggings.render_form
              :if={@mode == :add_tagging || @mode == :edit_tagging}
              mode={@mode}
              taggings={@taggings}
            />

            <div phx-click-away={if @mode == :sort_taggings, do: "taggings:mode:reset"}>
              <Taggings.render_sorting
                :if={@mode == :sort_taggings}
                taggings={@taggings}
              />
            </div>
          </:dialog>
        </Layouts.page_head>

        <div class="space-y-4 max-w-[80ch]" inert={@mode == :sort_taggings}>
          <Taggings.render_list
            dimensions={@taggings.dimensions}
            groups={@taggings.groups}
            own_profile?={@taggings.own_profile?}
            scope={@scope}
          />

          <div>Member for: {Utils.Time.relative(@profile.inserted_at)}</div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp find_profile(scope, slug) do
    Membership
    |> Ash.Query.filter(space_id == ^scope.space.id and slug == ^slug)
    |> Ash.read_one(not_found_error?: true, scope: scope)
  end
end
