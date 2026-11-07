defmodule LexWeb.PageLive.Editing.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:editing]

  attr :active?, :boolean, required: true

  def render(assigns) do
    ~H"""
    <button
      aria-label={button_label(@active?, @editing.checkpointing?)}
      aria-pressed={@active?}
      class={[
        "btn btn-sm btn-circle btn-neutral hover:btn-info",
        @active? && "btn-info"
      ]}
      disabled={@editing.checkpointing?}
      phx-click={delegate_event("toggle")}
      title={button_label(@active?, @editing.checkpointing?)}
      type="button"
    >
      <.icon :if={@active?} name="hero-check-micro" />
      <.icon :if={!@active?} name="hero-pencil-mini" />
    </button>
    """
  end

  defp button_label(_, true), do: "Saving document"
  defp button_label(true, false), do: "End editing"
  defp button_label(_, false), do: "Enable editing"
end
