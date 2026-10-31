defmodule LexWeb.PageLive.Editing.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:editing]

  def render(assigns) do
    ~H"""
    <button
      aria-label={button_label(@live_action, @editing.checkpointing?)}
      aria-pressed={@live_action == :editing}
      class={[
        "btn btn-square rounded-box",
        @live_action == :editing && "btn-info"
      ]}
      disabled={@editing.checkpointing?}
      phx-click={delegate_event("toggle")}
      title={button_label(@live_action, @editing.checkpointing?)}
      type="button"
    >
      <.icon :if={@live_action == :editing} name="hero-check-micro" />
      <.icon :if={@live_action != :editing} name="hero-pencil-mini" />
    </button>
    """
  end

  defp button_label(_live_action, true), do: "Saving document"
  defp button_label(:editing, false), do: "End editing"
  defp button_label(_live_action, false), do: "Enable editing"
end
