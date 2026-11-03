defmodule LexWeb.Components.Drawer do
  use LexWeb, :html

  attr :open?, :boolean, required: true
  attr :close_event, :string, required: true
  slot :aside, required: true
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div
      class={[
        "sm:grid sm:grid-cols-[auto_minmax(0,1fr)]",
        "h-full"
      ]}
      data-drawer-open={to_string(@open?)}
      data-testid="drawer"
    >
      <div class="order-2 min-w-0 max-sm:mt-14">
        {render_slot(@inner_block)}
      </div>

      <.backdrop
        close_event={@close_event}
        open?={@open?}
      />

      <div class={[
        "max-sm:z-50",
        @open? && "w-42",
        !@open? && "w-12 overflow-hidden",
        "max-sm:fixed",
        "max-sm:inset-0",
        !@open? && "max-sm:-left-13",
        "transition-[width] translition-[left] duration-200 ease-in-out",
        "bg-base-300/50 backdrop-blur-lg",
        "border-r border-base-content/20"
      ]}>
        {render_slot(@aside)}
      </div>
    </div>
    """
  end

  def backdrop(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@close_event}
      aria-label="open sidebar"
      class={[
        "sm:hidden",
        "cursor-pointer",
        !@open? && "pointer-events-none",
        "transition",
        @open? && "bg-base-200/50",
        "fixed",
        "inset-0",
        "z-40"
      ]}
    ></button>
    """
  end
end
