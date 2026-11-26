defmodule LexWeb.Components.Avatar do
  use LexWeb, :html

  alias Lex.Accounts.Membership
  alias Lex.Accounts.User

  attr :user, :map, required: true
  attr :class, :string, default: ""
  attr :size, :string, default: "md"

  def render(assigns) do
    {display_name, hue} = appearance(assigns.user)
    initials = String.slice(display_name, 0..1)

    color =
      "oklch(var(--collaboration-color-lightness) var(--collaboration-color-chroma) #{hue}deg)"

    size_class =
      case assigns.size do
        "xl" -> "size-12"
        "md" -> "size-6"
      end

    assigns =
      assigns
      |> assign(color: color)
      |> assign(initials: initials)
      |> assign(size_class: size_class)

    ~H"""
    <div class={[
      "avatar",
      @class
    ]}>
      <div
        class={[
          @size_class,
          "rounded-full",
          "flex items-center justify-center"
        ]}
        style={"background: #{@color}"}
      >
        <div class="avatar text-[0.7rem] font-bold small-caps text-white">{@initials}</div>
      </div>
    </div>
    """
  end

  defp appearance(%Membership{display_name: name, user: %User{hue: hue}}), do: {name, hue}
  defp appearance(%{display_name: name, hue: hue}), do: {name, hue}
end
