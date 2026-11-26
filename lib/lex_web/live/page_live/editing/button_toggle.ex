defmodule LexWeb.PageLive.Editing.ButtonToggle do
  use LexWeb, :html
  use LiveDelegate, path: [:editing]

  alias LexWeb.Layouts

  attr :active?, :boolean, required: true

  def render(assigns) do
    ~H"""
    <Layouts.action_button
      active?={@active?}
      data-testid="editing-toggle"
      disabled={@editing.saving?}
      title={button_label(@active?, @editing.saving?)}
      phx-click={delegate_event("toggle")}
      icon="hero-pencil-mini"
    />
    """
  end

  defp button_label(_, true), do: "Saving document"
  defp button_label(true, false), do: "End editing"
  defp button_label(_, false), do: "Enable editing"
end
