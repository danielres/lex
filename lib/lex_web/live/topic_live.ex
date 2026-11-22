defmodule LexWeb.TopicLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Topics.Topic
  alias LexWeb.Layouts
  alias LexWeb.Router.Path
  alias LexWeb.TopicLive.Edition
  alias LexWeb.UI

  delegate(:edition, Edition)
  delegate(:ui, UI)

  require Ash.Query

  @impl true
  def mount(params, session, socket) do
    scope = socket.assigns.scope
    slug = params["topic_slug"]
    result = find_topic(scope, slug)

    case result do
      {:ok, topic} ->
        socket =
          socket
          |> assign(:topic, topic)
          |> assign(:mode, :view)
          |> delegate_mount(params, session)

        {:ok, socket}

      {:error, _error} ->
        {:ok,
         socket
         |> assign(:topic, nil)
         |> Toast.put_toast(:error, "Topic not found")
         |> push_navigate(to: ~p"/#{scope.space.slug}")}
    end
  end

  @impl true
  def handle_event("toggle_mode:edit", _params, socket) do
    mode = if socket.assigns.mode == :edit, do: :view, else: :edit
    socket = socket |> assign(mode: mode)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="topics"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <div
        phx-click-away={if @mode == :edit, do: "toggle_mode:edit"}
        phx-key="escape"
        phx-window-keydown={if @mode == :edit, do: "toggle_mode:edit"}
      >
        <Layouts.page_head dialog?={@mode == :edit}>
          <:title>
            <.link navigate={Path.topics(@scope)} class="opacity-80 hover:opacity-100 transition">Topics</.link>
          </:title>
          <:title>{@topic.name}</:title>
          <:actions><.action_buttons mode={@mode} /></:actions>
          <:dialog><Edition.render_form edition={@edition} /></:dialog>
        </Layouts.page_head>
      </div>

      <div>Added: {Utils.Time.relative(@topic.inserted_at)}</div>
    </Layouts.app>
    """
  end

  defp find_topic(scope, slug) do
    Topic
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one(scope: scope)
  end

  attr :mode, :atom, required: true

  def action_buttons(assigns) do
    ~H"""
    <button
      :if={@mode == :view || @mode == :edit}
      type="button"
      phx-click="toggle_mode:edit"
      class={[
        "btn btn-circle btn-xs",
        @mode == :edit && "btn-info"
      ]}
    >
      <.icon :if={@mode == :view} name="hero-pencil-micro" />
      <.icon :if={@mode == :edit} name="hero-x-mark-micro" />
    </button>
    """
  end
end
