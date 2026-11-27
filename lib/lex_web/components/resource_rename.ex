defmodule LexWeb.Components.ResourceRename do
  use LexWeb, :html

  alias LexWeb.Live.Components

  attr :event, :string, required: true
  attr :rest, :global

  def button_edit(assigns) do
    ~H"""
    <button type="button" class="clickable" phx-click={@event} {@rest}>
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :path_prefix, :string, required: true
  attr :cancel_event, :string, required: true
  attr :change_event, :string, required: true
  attr :save_event, :string, required: true
  attr :cancel_testid, :string, default: nil
  attr :rest, :global
  slot :actions

  def render_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id={@id}
      phx-change={@change_event}
      phx-submit={@save_event}
      tabindex="-1"
      class="space-y-2"
      {@rest}
    >
      <input
        aria-label={@label}
        autocomplete="off"
        class={["input input-lg w-full", @field.errors != [] && "input-error"]}
        id={@field.id}
        name={@field.name}
        phx-hook="CapitalizeFirstLetter"
        phx-key="Escape"
        phx-keydown={@cancel_event}
        value={@field.value}
        phx-mounted={JS.focus() |> JS.dispatch("focus-at-end")}
      />

      <Components.slug_preview form={@form} prefix={@path_prefix} />

      <p
        :for={{message, _options} <- @field.errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-error"
      >
        <.icon name="hero-exclamation-circle" class="size-5" />
        {message}
      </p>

      <div class="flex gap-2">
        {render_slot(@actions)}
        <button
          class="btn btn-ghost ml-auto"
          data-testid={@cancel_testid}
          phx-click={@cancel_event}
          type="button"
        >
          Cancel
        </button>

        <button type="submit" phx-disable-with="Saving..." class="btn btn-info">
          Rename
        </button>
      </div>
    </.form>
    """
  end
end
