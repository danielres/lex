defmodule LexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LexWeb, :html

  alias LexWeb.Layouts.Drawer
  alias LexWeb.Layouts.Navbar

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :active, :string, default: ""
  attr :scope, :map, required: true
  attr :socket, :any, required: true
  attr :ui, :map, required: true

  slot :inner_block, required: true
  slot :page_head, required: false

  def app(assigns) do
    ~H"""
    <div class="flex min-h-dvh flex-col">
      <div class={[
        "max-sm:fixed",
        "max-sm:top-0",
        "max-sm:w-full",
        "max-sm:z-40",
        "max-sm:transition",
        "shrink-0",
        @ui.drawer_open? && "max-sm:opacity-0"
      ]}>
        <Navbar.render
          drawer_open?={@ui.drawer_open?}
          scope={@scope}
        />
      </div>

      <Drawer.render
        active={@active}
        open?={@ui.drawer_open?}
        scope={@scope}
        socket={@socket}
      >
        {render_slot(@page_head)}

        <main class={[
          "w-full min-w-0 max-w-[90ch] mx-auto",
          "flex flex-1 flex-col",
          "max-sm:mt-26",
          "sm:px-8",
          "sm:py-4"
        ]}>
          {render_slot(@inner_block)}
        </main>
      </Drawer.render>
    </div>

    <Toast.toast_group flash={@flash} connection_toasts={true} theme="system" rich_colors={false} />
    """
  end

  attr :dialog?, :boolean, default: false
  attr :close_event, :string, required: false

  slot :actions, required: false
  slot :dialog, required: false
  slot :title, required: true
  slot :crumb, required: false

  def page_head(assigns) do
    ~H"""
    <button
      :if={assigns[:close_event]}
      class={[
        @dialog? && "bg-base-200/30 hover:bg-base-200/10 transition",
        @dialog? && "cursor-pointer",
        @dialog? && "fixed inset-0 z-20"
      ]}
      phx-click={@close_event}
      type="button"
    />

    <div class={[
      "max-sm:fixed max-sm:w-full sm:sticky max-sm:top-10 sm:top-0 z-20",
      !@dialog? && "bg-base-200",
      @dialog? && "bg-base-300/20 backdrop-blur border-b border-base-content/20"
    ]}>
      <div class={[
        "border-b border-base-content/10 py-2"
      ]}>
        <div class={[
          "min-w-0 max-w-[90ch] mx-auto px-2 sm:px-8"
        ]}>
          <div class={[
            "flex items-end gap-2"
          ]}>
            <h2 class="grow text-lg sm:text-xl">
              <div class="flex items-center gap-1 text-sm">
                <%= for crumb <- @crumb do %>
                  <span class="leading-none">{render_slot(crumb)}</span>
                  <.icon
                    name="hero-chevron-right-micro"
                    class="size-3 opacity-60"
                  />
                <% end %>

                <span class="opacity-50">&nbsp;</span>
              </div>

              <%= for {title, index} <- Enum.with_index(@title) do %>
                <.icon
                  :if={index > 0}
                  name="hero-chevron-right-micro"
                  class="size-4 opacity-60"
                />
                <span class="leading-none">{render_slot(title)}</span>
              <% end %>
            </h2>
            {render_slot(@actions)}
          </div>

          <div
            id="layout-dialog-wrapper"
            phx-hook="AutoAnimate"
            data-auto-animate-resize-only
            class={[
              "relative",
              @dialog? && "py-2"
            ]}
          >
            {render_slot(@dialog)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :active?, :boolean, default: false
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :rest, :global, include: ~w(disabled)

  def action_button(assigns) do
    attrs =
      Map.merge(assigns.rest, %{
        "aria-label": assigns.title,
        title: assigns.title,
        class: [
          "btn btn-sm btn-circle hover:btn-info",
          assigns.active? && "btn-info"
        ]
      })

    assigns = assign(assigns, :attrs, attrs)

    ~H"""
    <.link :if={@patch || @navigate} patch={@patch} navigate={@navigate} {@attrs}>
      <.icon name={@icon} />
    </.link>
    <button :if={is_nil(@patch) && is_nil(@navigate)} type="button" {@attrs}>
      <.icon name={@icon} />
    </button>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
