defmodule LexWeb.PageLive.Editing.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:editing]

  def render(assigns) do
    ~H"""
    <button
      aria-label={button_label(@editing)}
      aria-pressed={!@editing.enabled?}
      class={[
        "btn btn-square rounded-box",
        @editing.enabled? && "btn-info"
      ]}
      disabled={@editing.checkpointing? || @disabled}
      phx-click={delegate_event("toggle")}
      title={button_label(@editing)}
      type="button"
    >
      <.icon
        name={
          if @editing.enabled?,
            do: "hero-lock-open-solid",
            else: "hero-lock-closed-solid"
        }
        class="size-4"
      />
    </button>
    """
  end

  defp button_label(%{checkpointing?: true}), do: "Saving document"
  defp button_label(%{enabled?: true}), do: "Make editor read-only"
  defp button_label(_editing), do: "Enable editing"
end
