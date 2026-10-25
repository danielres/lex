defmodule LexWeb.PageLive.Editing.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:editing]

  def render(assigns) do
    ~H"""
    <button
      aria-label={if @editing.enabled?, do: "Make editor read-only", else: "Enable editing"}
      aria-pressed={!@editing.enabled?}
      class={[
        "btn btn-square rounded-box",
        @editing.enabled? && "btn-info"
      ]}
      phx-click={delegate_event("toggle")}
      title={if @editing.enabled?, do: "Make editor read-only", else: "Enable editing"}
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
end
