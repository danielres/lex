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
  attr :editing?, :boolean, default: false
  attr :scope, :map, required: true
  attr :socket, :any, required: true
  attr :ui, :map, required: true

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="h-full">
      <div class={[
        "max-sm:fixed",
        "max-sm:top-0",
        "max-sm:w-full",
        "max-sm:z-40",
        "max-sm:transition",
        @ui.drawer_open? && "max-sm:opacity-0",
        @editing? && "max-sm:opacity-0"
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
        <main class="min-w-0 max-w-[90ch] mx-auto p-2 sm:p-8">
          {render_slot(@inner_block)}
        </main>
      </Drawer.render>
    </div>

    <Toast.toast_group flash={@flash} connection_toasts={true} theme="system" rich_colors={false} />
    """
  end

  attr :dialog?, :boolean, default: false

  slot :actions, required: false
  slot :dialog, required: false
  slot :title, required: true

  def page_head(assigns) do
    ~H"""
    <div class="mb-4">
      <div class={[
        "text-xl border-b-2 border-base-content/20 pb-2",
        @dialog? && "border-none",
        "flex items-end gap-2"
      ]}>
        <h2 class="grow flex items-center gap-2">
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
        class={[
          "relative",
          @dialog? && "bg-base-300/60 rounded px-6 py-4",
          @dialog? && "border-2 border-base-content/30"
        ]}
      >
        {render_slot(@dialog)}
      </div>
    </div>
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
