defmodule LexWeb.TopicLive.Taggings do
  use LexWeb, :live_view
  use LiveDelegate, path: [:taggings]

  alias Lex.Topics.Dimensions
  alias Lex.Topics.Tagging
  alias LexWeb.Components.Avatar
  alias LexWeb.Live.Tagging.Components
  alias LexWeb.Live.Tagging.Sorting
  alias LexWeb.Router.Path

  def on_mount(_params, _session, socket) do
    socket
    |> delegate_assign(%{
      sorting: Sorting.load(socket, :topic_taggings),
      dimensions: Dimensions.all_for("membership"),
      subscribed_topic: nil
    })
  end

  def load_topic(socket) do
    topic = socket.assigns.topic
    previous = socket.assigns.taggings.subscribed_topic

    socket =
      if connected?(socket) && (!previous || previous.id != topic.id) do
        if previous do
          Phoenix.PubSub.unsubscribe(Lex.PubSub, Tagging.pub_sub_topic(previous))
        end

        Phoenix.PubSub.subscribe(Lex.PubSub, Tagging.pub_sub_topic(topic))
        delegate_assign(socket, :subscribed_topic, topic)
      else
        socket
      end

    reload(socket)
  end

  defp reload(socket) do
    %{topic: topic, scope: scope, taggings: %{sorting: sorting}} = socket.assigns

    case Tagging.present_for_topic(topic, sorting, scope: scope) do
      {:ok, groups} ->
        socket
        |> delegate_assign(:status, if(groups == [], do: :empty, else: :ready))
        |> delegate_assign(:members, groups)

      {:error, _error} ->
        socket
        |> delegate_assign(:status, :error)
        |> delegate_assign(:members, [])
    end
  end

  @impl true
  def handle_event("sort", %{"by" => by}, socket) do
    case Sorting.change(socket.assigns.taggings.sorting, by) do
      {:ok, sorting} ->
        socket =
          socket
          |> delegate_assign(:sorting, sorting)
          |> reload()
          |> Sorting.persist(:topic_taggings, sorting)

        {:noreply, socket}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{data: %{topic_id: id}}, socket) when id == socket.assigns.topic.id do
    {:noreply, reload(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  attr :taggings, :map, required: true

  def render_sorting(assigns) do
    ~H"""
    <Components.sort_controls
      alpha_label="Member name"
      event={delegate_event("sort")}
      sorting={@taggings.sorting}
    />
    """
  end

  attr :scope, :map, required: true
  attr :taggings, :map, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-3">
      <%!-- <h3 class="small-caps">Members</h3> --%>
      <%!-- <p :if={@taggings.status == :empty} class="opacity-60">No members tagged with this topic yet</p> --%>
      <p :if={@taggings.status == :error} role="alert">Could not load members for this topic</p>

      <Components.cards>
        <Components.card :for={group <- @taggings.members} id={"tagged_members-#{group.id}"}>
          <:title>
            <.link class="clickable flex gap-3 items-center" navigate={Path.to(@scope, group.tagged_membership)}>
              <Avatar.render  user={group.tagged_membership} />
              {group.tagged_membership.display_name}
            </.link>
          </:title>

          <Components.assessment
            :if={group.self_assessment}
            dimensions={@taggings.dimensions}
            levels={group.self_assessment.dimensions}
            text={group.self_assessment.text}
          />

          <Components.endorsements :if={group.endorsements != []}>
            <Components.endorsement
              :for={endorsement <- group.endorsements}
              endorsement={endorsement}
              scope={@scope}
            />
          </Components.endorsements>
        </Components.card>
      </Components.cards>
    </section>
    """
  end
end
