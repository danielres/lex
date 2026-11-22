defmodule LexWeb.MemberLive.Taggings do
  use LexWeb, :live_view
  use LiveDelegate, path: [:taggings]

  alias Lex.Scope
  alias Lex.Topics.Dimensions
  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic
  alias LexWeb.Live.Components
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
    <div id="profile-taggings" class="space-y-2" phx-hook="AutoAnimate">
      <p :if={@groups == []} class="opacity-60">No topics assigned yet</p>

      <div
        :for={group <- @groups}
        id={"profile-topic-#{group.topic.id}"}
        class="rounded-lg bg-base-300/50 px-4 py-3"
      >
        <div class="flex items-start gap-3">
          <.link class="clickable font-semibold" navigate={Path.to(@scope, group.topic)}>
            {group.topic.name}
          </.link>

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
        </div>

        <div :if={group.self_assessment} class="mt-2 mb-3 flex flex-wrap gap-4">
          <%= for dimension <- @dimensions do %>
            <% level = group.self_assessment.dimensions |> Map.get(dimension.key, 0) %>
            <.dimension :if={level > 0} dimension={dimension} level={level} />
          <% end %>
        </div>

        <Components.text_preview
          :if={group.self_assessment && group.self_assessment.text}
          class={["text-sm", "opacity-80"]}
          text={group.self_assessment.text}
        />

        <div :if={group.endorsements != []} class="mt-4 space-y-2">
          <h3 class={[
            "small-caps opacity-80",
            "flex items-center gap-2"
          ]}>
            <div>Endorsements</div>
            <div class="border-t grow h-0 border-base-content/20" />
          </h3>

          <.endorsement
            :for={endorsement <- group.endorsements}
            endorsement={endorsement}
            scope={@scope}
            topic={group.topic}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :text, :string, required: true
  attr :class, :any, default: ""

  def blockquote(assigns) do
    ~H"""
    <Components.text_preview
      class={[
        "text-sm",
        "opacity-60",
        "border-l-4 pl-3 ml-0 border-base-content/20",
        @class
      ]}
      text={@text}
    />
    """
  end

  attr(:endorsement, Tagging, required: true)
  attr(:topic, Topic, required: true)
  attr(:scope, Scope, required: true)

  defp endorsement(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="flex items-center gap-1">
        <span class="text-sm opacity-80">
          <span class="opacity-80">by</span>
          <.link navigate={Path.to(@scope, @endorsement.tagged_by_membership)} class="clickable">
            {@endorsement.tagged_by_membership.display_name}
          </.link>
        </span>

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
      </div>

      <.blockquote :if={@endorsement.text} text={@endorsement.text} />
    </div>
    """
  end

  attr :dimension, :map, required: true
  attr :level, :integer, required: true
  attr :class, :any, default: "w-24 h-2"

  defp dimension(assigns) do
    ~H"""
    <div
      class={[
        "stacked",
        "tooltip",
        @class
      ]}
      style={"--tt-bg:#{@dimension.color}"}
    >
      <div
        class="rounded-sm h-full w-full opacity-20"
        style={"background-color: #{@dimension.color}"}
      />
      <div
        class="rounded-sm h-full"
        style={"background-color: #{@dimension.color}; width: #{100/@dimension.max*@level}%"}
      />
      <div class="tooltip-content">
        <span class="font-bold">{@dimension.label}:</span> {@level}/{@dimension.max}
      </div>
    </div>
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
