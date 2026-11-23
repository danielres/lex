defmodule LexWeb.MemberLive.Taggings.Form do
  use LexWeb, :live_view
  use LiveDelegate, path: [:taggings, :form]

  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic
  alias LexWeb.Live.Components.Combobox

  def on_mount(_params, _session, socket) do
    scope = socket.assigns.scope
    topics = Topic |> Ash.read!(scope: scope)
    {options_json, suggested_values_json} = topics |> combobox_options()
    own_profile? = socket.assigns.taggings.own_profile?
    dimensions = if own_profile?, do: socket.assigns.taggings.dimensions, else: []

    delegate_assign(socket, %{
      data: make_form(),
      dimensions: dimensions,
      options_json: options_json,
      own_profile?: own_profile?,
      suggested_values_json: suggested_values_json,
      topics: topics
    })
  end

  @impl true
  def handle_event("new", %{"topic-id" => topic_id}, socket) do
    {:noreply, select_topic(socket, topic_id)}
  end

  def handle_event("new", _params, socket) do
    socket =
      socket
      |> delegate_assign(:data, make_form())
      |> assign(:mode, :add_tagging)

    {:noreply, socket}
  end

  def handle_event("edit", %{"id" => tagging_id}, socket) do
    tagging = Tagging |> Ash.get!(tagging_id, scope: socket.assigns.scope)

    socket =
      socket
      |> delegate_assign(:data, make_form(tagging))
      |> assign(:mode, :edit_tagging)

    {:noreply, socket}
  end

  def handle_event("validate", %{"tagging" => params}, socket) do
    selected_topic_id = params["topic_id"]
    current_form = socket.assigns.taggings.form.data
    current_topic_id = current_form |> Phoenix.HTML.Form.input_value(:topic_id)

    socket =
      if selected_topic_id == current_topic_id do
        socket |> delegate_assign(:data, make_form(params))
      else
        socket |> select_topic(selected_topic_id)
      end

    {:noreply, socket}
  end

  def handle_event("save", %{"tagging" => params}, socket) do
    profile = socket.assigns.profile
    scope = socket.assigns.scope
    tagged_by_membership = socket.assigns.scope.membership
    topic_id = params["topic_id"]
    topics = socket.assigns.taggings.form.topics
    topic = topics |> Enum.find(&(&1.id == topic_id))

    content = %{
      dimensions: dimensions_from_params(params, socket.assigns.taggings.form.own_profile?),
      text: params["text"]
    }
    dbg(profile)
    case Tagging.set(profile, topic, tagged_by_membership, content, scope: scope) do
      {:ok, nil} ->
        socket =
          socket
          |> delegate_assign(:data, make_form(params))
          |> assign(:mode, :add_tagging)
          |> Toast.put_toast(:info, "Topic removed")

        {:noreply, socket}

      {:ok, tagging} ->
        socket =
          socket
          |> delegate_assign(:data, make_form(tagging))
          |> assign(:mode, :edit_tagging)
          |> Toast.put_toast(:info, "Topic saved")

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, Toast.put_toast(socket, :error, "Could not save topic")}
    end
  end

  def handle_event("remove", %{"topic-id" => topic_id}, socket) do
    profile = socket.assigns.profile
    scope = socket.assigns.scope
    tagged_by_membership = socket.assigns.scope.membership
    topics = socket.assigns.taggings.form.topics
    topic = topics |> Enum.find(&(&1.id == topic_id))

    case Tagging.remove(profile, topic, tagged_by_membership, scope: scope) do
      {:ok, _tagging} ->
        socket =
          socket
          |> delegate_assign(:data, make_form(%{"topic_id" => topic.id}))
          |> assign(:mode, :add_tagging)
          |> Toast.put_toast(:info, "Topic removed")

        {:noreply, socket}

      {:error, _error} ->
        socket = socket |> Toast.put_toast(:error, "Could not remove topic")
        {:noreply, socket}
    end
  end

  attr(:form, :map, required: true)
  attr(:mode, :atom, required: true)

  @impl true
  def render(assigns) do
    topic_id = assigns.form.data |> Phoenix.HTML.Form.input_value(:topic_id)
    topics = assigns.form.topics
    topic = topics |> Enum.find(&(&1.id == topic_id))

    assigns = assigns |> assign(:topic, topic)

    ~H"""
    <.form
      class="space-y-4"
      for={@form.data}
      id="profile-tagging-form"
      phx-change={delegate_event("validate")}
      phx-hook="ScrollToTop"
      phx-submit={delegate_event("save")}
    >
      <Combobox.field
        display_value={@topic && @topic.name}
        empty_message="No matching topic"
        field={@form.data[:topic_id]}
        id="profile-tagging-topic"
        label="Topic"
        options_json={@form.options_json}
        placeholder="Search topics"
        suggested_values_json={@form.suggested_values_json}
      />

      <div
        class={[
          "transition-[filter,opacity] duration-300",
          @topic && "saturate-100 opacity-100",
          !@topic && "saturate-0 opacity-10"
        ]}
        inert={!@topic}
      >
        <div class="space-y-2">
          <.dimension
            :for={dimension <- @form.dimensions}
            dimension={dimension}
            form={@form}
          />
        </div>

        <.input
          field={@form.data[:text]}
          label={if @form.own_profile?, do: "Notes", else: "Endorsement"}
          placeholder={
            if @form.own_profile?, do: "Share a little more", else: "What would you like to say?"
          }
          type="textarea"
        />
      </div>

      <div class="flex gap-2">
        <button
          :if={@mode == :edit_tagging}
          type="button"
          class="btn hover:btn-error btn-soft"
          phx-click={delegate_event("remove")}
          phx-value-topic-id={@topic.id}
          data-confirm={
            if @form.own_profile?,
              do: ~s(Remove your assessment about "#{@topic.name}"?),
              else: ~s(Remove your endorsement about "#{@topic.name}"?)
          }
        >
          Remove
        </button>

        <button
          type="submit"
          class="btn btn-info ml-auto"
          disabled={is_nil(@topic)}
          phx-disable-with="Saving..."
        >
          <%= if @form.own_profile? do %>
            <span :if={@mode == :add_tagging}>Add topic</span>
            <span :if={@mode == :edit_tagging}>Update topic</span>
          <% else %>
            <span :if={@mode == :add_tagging}>Add endorsement</span>
            <span :if={@mode == :edit_tagging}>Update endorsement</span>
          <% end %>
        </button>
      </div>
    </.form>
    """
  end

  attr(:dimension, :map, required: true)
  attr(:form, :map, required: true)

  defp dimension(assigns) do
    ~H"""
    <div>
      <label
        for={@form.data[@dimension.field].id}
        class="flex items-center justify-between gap-4 text-sm"
      >
        <span>{@dimension.label}</span>
      </label>

      <input
        id={@form.data[@dimension.field].id}
        name={@form.data[@dimension.field].name}
        value={@form.data[@dimension.field].value}
        type="range"
        min="0"
        max={@dimension.max}
        step="1"
        class="range range-xs w-full"
        style={"color: #{@dimension.color}"}
      />
    </div>
    """
  end

  defp select_topic(socket, "") do
    socket
    |> delegate_assign(:data, make_form())
    |> assign(:mode, :add_tagging)
  end

  defp select_topic(socket, topic_id) do
    profile = socket.assigns.profile
    scope = socket.assigns.scope
    tagged_by_membership = socket.assigns.scope.membership
    topics = socket.assigns.taggings.form.topics
    topic = topics |> Enum.find(&(&1.id == topic_id))

    {:ok, tagging} = Tagging.get(profile, topic, tagged_by_membership, scope: scope)

    case tagging do
      nil ->
        socket
        |> delegate_assign(:data, make_form(%{"topic_id" => topic_id}))
        |> assign(:mode, :add_tagging)

      tagging ->
        socket
        |> delegate_assign(:data, make_form(tagging))
        |> assign(:mode, :edit_tagging)
    end
  end

  defp make_form(params \\ %{})

  defp make_form(%Tagging{} = tagging) do
    tagging.dimensions
    |> Map.put("text", tagging.text || "")
    |> Map.put("topic_id", tagging.topic_id)
    |> make_form()
  end

  defp make_form(params) when is_map(params) do
    params =
      %{
        "interest" => "0",
        "experience" => "0",
        "text" => "",
        "topic_id" => ""
      }
      |> Map.merge(params)

    params |> to_form(as: :tagging)
  end

  defp dimensions_from_params(params, true) do
    %{
      "interest" => String.to_integer(params["interest"]),
      "experience" => String.to_integer(params["experience"])
    }
  end

  defp dimensions_from_params(_params, false), do: %{}

  defp combobox_options(topics) do
    options = topics |> Enum.map(&%{label: &1.name, value: &1.id})
    suggested_values = options |> Enum.map(& &1.value) |> Enum.take(8)

    {Jason.encode!(options), Jason.encode!(suggested_values)}
  end
end
