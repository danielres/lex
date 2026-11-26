defmodule LexWeb.MemberLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Accounts.Membership
  alias Lex.Topics.Tagging
  alias LexWeb.Components.Avatar
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
         |> push_navigate(to: Path.to(scope.space))}
    end
  end

  @impl true
  def handle_info(%{resource: Tagging} = message, socket) do
    Taggings.handle_info(message, socket)
  end

  defp dialog?(mode) do
    mode != :view
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
      <:page_head>
        <Layouts.page_head dialog?={dialog?(@mode)}>
          <:crumb>
            <.link navigate={Path.members(@scope)} class="opacity-80 hover:opacity-100 transition">Members</.link>
          </:crumb>
          <:title>
            {@profile.display_name}
          </:title>
          <:actions><Taggings.render_actions mode={@mode} /></:actions>
          <:dialog>
            <Taggings.render_form
              :if={@mode == :add_tagging || @mode == :edit_tagging}
              mode={@mode}
              taggings={@taggings}
            />

            <Taggings.render_sorting :if={@mode == :sort_taggings} taggings={@taggings} />
          </:dialog>
        </Layouts.page_head>
      </:page_head>

      <div class="space-y-4" inert={@mode == :sort_taggings}>
        <Avatar.render size="xl" class="reactive" user={@profile} />

        <Taggings.render_list
          dimensions={@taggings.dimensions}
          groups={@taggings.groups}
          own_profile?={@taggings.own_profile?}
          scope={@scope}
        />

        <div>Member for: {Utils.Time.relative(@profile.inserted_at)}</div>
      </div>
    </Layouts.app>
    """
  end

  defp find_profile(scope, slug) do
    Membership
    |> Ash.Query.for_read(:active)
    |> Ash.Query.filter(space_id == ^scope.space.id and slug == ^slug)
    |> Ash.read_one(not_found_error?: true, scope: scope)
  end
end
