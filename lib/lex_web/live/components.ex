defmodule LexWeb.Live.Components do
  use LexWeb, :html

  attr :form, :map, required: true
  attr :prefix, :string, default: "/"

  def slug_preview(assigns) do
    slug = assigns.form |> AshPhoenix.Form.value(:slug) || ""
    assigns = assigns |> assign(slug_preview: slug)

    ~H"""
    <span :if={@form.errors == []} class="font-mono opacity-50 flex">
      <span class={[@slug_preview == "" && "opacity-0"]}>{@prefix}</span>
      <span>{@slug_preview}</span>
    </span>
    """
  end

  attr :text, :string, required: true
  attr :class, :any, default: ""

  def text_preview(assigns) do
    paragraphs = String.split(assigns.text, ~r/\s*\R\s*/, trim: true)
    assigns = assign(assigns, :paragraphs, paragraphs)

    ~H"""
    <div class={@class}>
      <p :for={paragraph <- @paragraphs}>{paragraph}</p>
    </div>
    """
  end
end
