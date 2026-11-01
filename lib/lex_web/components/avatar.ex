defmodule LexWeb.Components.Avatar do
  use LexWeb, :html

  attr :user, :map, required: true

  def render(assigns) do
    initials = assigns.user.display_name |> String.slice(0..1)

    color =
      "oklch(var(--collaboration-color-lightness) var(--collaboration-color-chroma) #{assigns.user.hue}deg)"

    assigns =
      assigns
      |> assign(initials: initials)
      |> assign(color: color)

    ~H"""
    <div
      class={[
        "avatar",
        "tooltip tooltip-bottom",
        "cursor-default"
      ]}
      data-tip={@user.display_name}
    >
      <div
        class={[
          "size-6 rounded-full bg-base-100",
          "flex items-center justify-center"
        ]}
        style={"background: #{@color}"}
      >
        <div class="avatar text-[0.7rem] font-bold small-caps text-white">{@initials}</div>
      </div>
    </div>
    """
  end
end
