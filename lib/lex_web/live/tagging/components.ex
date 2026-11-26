defmodule LexWeb.Live.Tagging.Components do
  use LexWeb, :html

  alias Lex.Topics.Dimensions
  alias LexWeb.Components.Avatar
  alias LexWeb.Live.Components
  alias LexWeb.Router.Path

  def cards(assigns) do
    ~H"""
    <div id="taggings-list" class="space-y-3" phx-hook="AutoAnimate">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, required: true
  slot :title, required: true
  slot :action_buttons
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div id={@id} class="p-4 bg-base-100/40 rounded-lg">
      <div class="flex items-start gap-3">
        <span class="text-lg small-caps font-bold leading-none">{render_slot(@title)}</span>
        {render_slot(@action_buttons)}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :dimensions, :list, required: true
  attr :levels, :map, required: true
  attr :text, :string, default: nil

  def assessment(assigns) do
    ~H"""
    <div class="mt-2 mb-3 flex flex-wrap gap-4">
      <%= for definition <- @dimensions do %>
        <% level = Map.get(@levels, definition.key, 0) %>
        <.dimension :if={level > 0} dimension={definition} level={level} />
      <% end %>
    </div>
    <Components.text_preview :if={@text} class="text-sm opacity-80" text={@text} />
    """
  end

  slot :inner_block, required: true

  def endorsements(assigns) do
    ~H"""
    <div class="mt-4 space-y-2">
      <%!-- <h3 class="small-caps opacity-80 flex items-center gap-2"> --%>
      <%!--   <span>Endorsements</span> --%>
      <%!--   <span class="border-t grow h-0 border-base-content/20" /> --%>
      <%!-- </h3> --%>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :action_buttons
  attr :endorsement, :map, required: true
  attr :scope, :map, required: true

  def endorsement(assigns) do
    ~H"""
    <div class={
      [
        "flex gap-3",
        # "bg-base-200 px-3 py-2 rounded-lg",
        "border-t border-base-content/20 pt-3"
      ]
    }>
      <.link class="clickable" navigate={Path.to(@scope, @endorsement.tagged_by_membership)}>
        <Avatar.render
          class="reactive"
          user={@endorsement.tagged_by_membership}
        />
      </.link>

      <div class="grow">
        <div class="text-xs flex">
          <.link
            class="clickable"
            navigate={Path.to(@scope, @endorsement.tagged_by_membership)}
          >
            {@endorsement.tagged_by_membership.display_name}
          </.link>

          <div class="ml-auto">{render_slot(@action_buttons)}</div>
        </div>

        <div class="">
          <Components.text_preview
            :if={@endorsement.text}
            class="text-sm text-base-content/50"
            text={@endorsement.text}
          />
        </div>
      </div>
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

  attr :alpha_label, :string, required: true
  attr :event, :string, required: true
  attr :sorting, :map, required: true

  def sort_controls(assigns) do
    ~H"""
    <h3 class="small-caps">Sort by</h3>

    <ul class="grid gap-2">
      <li>
        <.sorting_button
          phx-click={@event}
          phx-value-by="interest"
        >
          <.direction value={direction(@sorting, :interest)} />
          <.sort_dimension dimension="interest" />
          <span class="text-sm opacity-80">Interest</span>
        </.sorting_button>
      </li>

      <li>
        <.sorting_button
          phx-click={@event}
          phx-value-by="experience"
        >
          <.direction value={direction(@sorting, :experience)} />
          <.sort_dimension dimension="experience" />
          <span class="text-sm opacity-80">Experience</span>
        </.sorting_button>
      </li>

      <li>
        <.sorting_button
          phx-click={@event}
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
          <span class="text-sm opacity-80">{@alpha_label}</span>
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

  defp sort_dimension(assigns) do
    ~H"""
    <div
      class="mx-0.5 size-3 rounded-full"
      style={"background: #{Dimensions.get!("membership", @dimension).color}"}
    />
    """
  end

  defp direction(%{by: by, direction: direction}, by), do: direction
  defp direction(_sorting, _by), do: nil
end
