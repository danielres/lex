defmodule LexWeb.PageLive.ButtonToggleEdit do
  use LexWeb, :html

  def render(assigns) do
    ~H"""
    <button
          aria-label={if @editable, do: "Make editor read-only", else: "Enable editing"}
          aria-pressed={!@editable}
          class={[
            "btn btn-square rounded-box",
            @editable && "btn-info"
          ]}
          phx-click="toggle_editable"
          title={if @editable, do: "Make editor read-only", else: "Enable editing"}
          type="button"
        >
          <.icon
            name={if @editable, do: "hero-lock-open-solid", else: "hero-lock-closed-solid"}
            class="size-4"
          />
        </button>

    

    
    """
  end

  
end
