defmodule LexWeb.Components.Dropdown do
  use LexWeb, :html

  attr :class, :string, default: "btn"
  attr :id, :string, required: true
  slot :inner_block, required: true
  slot :content, required: true

  def render(assigns) do
    ~H"""
    <button
      class={@class}
      popovertarget={@id}
      style={"anchor-name:--anchor-#{@id}"}
    >
      {render_slot(@inner_block)}
    </button>

    <div
      class="dropdown"
      popover
      id={@id}
      style={"position-anchor:--anchor-#{@id}"}
    >
      {render_slot(@content)}
    </div>
    """
  end
end
