defmodule LexWeb.Components.Tooltip do
  use LexWeb, :html

  slot :inner_block, required: true
  slot :tooltip, required: true
  attr :alignment, :string, default: "center", values: ~w(center start end)
  attr :direction, :string, default: "bottom", values: ~w(top bottom left right)
  attr :class, :string, default: "tooltip"

  def render(assigns) do
    alignment_class =
      case assigns.alignment do
        "start" -> "tooltip-start"
        "center" -> "tooltip-center"
        "end" -> "tooltip-end"
      end

    direction_class =
      case assigns.direction do
        "top" -> "tooltip-top"
        "bottom" -> "tooltip-bottom"
        "left" -> "tooltip-left"
        "right" -> "tooltip-right"
      end

    assigns =
      assigns
      |> assign(direction_class: direction_class)
      |> assign(alignment_class: alignment_class)

    ~H"""
    <div class={[
      @class,
      @alignment_class,
      @direction_class
    ]}>
      {render_slot(@inner_block)}
      <div class="tooltip-content">{render_slot(@tooltip)}</div>
    </div>
    """
  end
end
