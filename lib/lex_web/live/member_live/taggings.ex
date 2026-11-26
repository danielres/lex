defmodule LexWeb.MemberLive.Taggings do
  use LexWeb, :live_view
  use LiveDelegate, path: [:taggings]

  alias Lex.Scope
  alias Lex.Topics.Dimensions
  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic
  alias LexWeb.Live.Tagging.Components
  alias LexWeb.MemberLive.Taggings.Form
  alias LexWeb.MemberLive.Taggings.Sorting
  alias LexWeb.Router.Path

  delegate(:form, Form)
  delegate(:sorting, Sorting)

  def on_mount(params, session, socket) do
    profile = socket.assigns.profile
    own_profile? = profile.id == socket.assigns.scope.membership.id

    socket
    |> subscribe(profile)
    |> delegate_assign(%{
      dimensions: Dimensions.all_for("membership"),
      own_profile?: own_profile?
    })
    |> delegate_mount(params, session)
    |> reload()
  end

  defp subscribe(socket, profile) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Lex.PubSub, Tagging.pub_sub_topic(profile))
    end

    socket
  end

  defp reload(socket) do
    profile = socket.assigns.profile
    scope = socket.assigns.scope
    sorting = socket.assigns.taggings.sorting
    {:ok, groups} = Tagging.present_for_target(profile, sorting, scope: scope)

    socket |> delegate_assign(:groups, groups)
  end

  @impl true
  def handle_info(%{action: %{name: action}}, socket)
      when action in [:create, :destroy, :update] do
    {:noreply, reload(socket)}
  end

  @impl true
  def handle_event("mode:reset", _params, socket) do
    {:noreply, assign(socket, :mode, :view)}
  end

  def handle_event("remove", %{"id" => tagging_id}, socket) do
    scope = socket.assigns.scope

    result =
      with {:ok, tagging} <- Ash.get(Tagging, tagging_id, scope: scope) do
        Tagging.remove(tagging, scope: scope)
      end

    case result do
      {:ok, _tagging} ->
        socket =
          socket
          |> reload()
          |> Toast.put_toast(:info, "Endorsement removed")

        {:noreply, socket}

      {:error, _error} ->
        socket = socket |> Toast.put_toast(:error, "Could not remove endorsement")
        {:noreply, socket}
    end
  end

  attr(:mode, :atom, required: true)

  def render_actions(assigns) do
    ~H"""
    <button
      :if={@mode == :view}
      type="button"
      class="btn btn-circle btn-xs"
      phx-click={delegate_event("sorting:start")}
      aria-label="Sort"
    >
      <.icon name="hero-arrows-up-down" />
    </button>

    <button
      :if={@mode == :view}
      type="button"
      class="btn btn-circle btn-xs"
      phx-click={delegate_event("form:new")}
      aria-label="Add topic assessment"
    >
      <.icon name="hero-plus-micro" />
    </button>

    <button
      :if={@mode != :view}
      type="button"
      class="btn btn-circle btn-info btn-xs"
      phx-click={delegate_event("mode:reset")}
      aria-label="Close dialog"
    >
      <.icon name="hero-x-mark-micro" />
    </button>
    """
  end

  attr(:taggings, :map, required: true)

  def render_sorting(assigns) do
    ~H"""
    <Sorting.render sorting={@taggings.sorting} />
    """
  end

  attr(:mode, :atom, required: true)
  attr(:taggings, :map, required: true)

  def render_form(assigns) do
    ~H"""
    <Form.render form={@taggings.form} mode={@mode} />
    """
  end

  attr(:dimensions, :list, required: true)
  attr(:groups, :list, required: true)
  attr(:own_profile?, :boolean, required: true)
  attr(:scope, Scope, required: true)

  def render_list(assigns) do
    ~H"""
    <Components.cards>
      <%!-- <p :if={@groups == []} class="opacity-60">No topics assigned yet</p> --%>

      <Components.card :for={group <- @groups} id={"profile-topic-#{group.topic.id}"}>
        <:title>
          <.link class="clickable" navigate={Path.to(@scope, group.topic)}>
            {group.topic.name}
          </.link>
        </:title>

        <:action_buttons>
          <.button_edit
            :if={group.self_assessment && Ash.can?({group.self_assessment, :update}, @scope)}
            phx-click={delegate_event("form:edit")}
            phx-value-id={group.self_assessment.id}
            aria-label={"Edit #{group.topic.name} assessment"}
          />

          <.button_edit
            :if={@own_profile? && is_nil(group.self_assessment)}
            phx-click={delegate_event("form:new")}
            phx-value-topic-id={group.topic.id}
            aria-label={"Add #{group.topic.name} assessment"}
          />
        </:action_buttons>

        <Components.assessment
          :if={group.self_assessment}
          dimensions={@dimensions}
          levels={group.self_assessment.dimensions}
          text={group.self_assessment.text}
        />

        <Components.endorsements :if={group.endorsements != []}>
          <.endorsement
            :for={endorsement <- group.endorsements}
            endorsement={endorsement}
            scope={@scope}
            topic={group.topic}
          />
        </Components.endorsements>
      </Components.card>
    </Components.cards>
    """
  end

  attr(:endorsement, Tagging, required: true)
  attr(:topic, Topic, required: true)
  attr(:scope, Scope, required: true)

  defp endorsement(assigns) do
    ~H"""
    <Components.endorsement endorsement={@endorsement} scope={@scope}>
      <:action_buttons>
        <.button_edit
          :if={Ash.can?({@endorsement, :update}, @scope)}
          phx-click={delegate_event("form:edit")}
          phx-value-id={@endorsement.id}
          aria-label={"Edit #{@topic.name} endorsement"}
        />

        <button
          :if={
            Ash.can?({@endorsement, :destroy}, @scope) &&
              !Ash.can?({@endorsement, :update}, @scope)
          }
          type="button"
          class={[
            "btn btn-circle btn-ghost btn-xs hover:btn-error",
            "opacity-50 hover:opacity-100 transition",
            "ml-auto"
          ]}
          phx-click={delegate_event("remove")}
          phx-value-id={@endorsement.id}
          data-confirm={~s(Remove this endorsement from your profile?)}
          aria-label={"Remove #{@topic.name} endorsement"}
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </:action_buttons>
    </Components.endorsement>
    """
  end

  attr(:rest, :global)

  defp button_edit(assigns) do
    ~H"""
    <button
      type="button"
      class="btn btn-circle btn-ghost btn-xs hover:btn-info ml-auto"
      {@rest}
    >
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end
end
