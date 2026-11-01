defmodule LexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LexWeb, :html

  alias LexWeb.Components.Avatar
  alias LexWeb.Presences
  alias LexWeb.Layouts.Drawer

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

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :string, default: ""
  attr :presences, :list, default: []
  attr :user, :map, required: true

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-svh grid grid-rows-[auto_1fr]">
      <% drawer_dom_id = "layout-drawer" %>
      <.navbar user={@user} drawer_dom_id={drawer_dom_id} />

      <Drawer.render {assigns} presences={@presences} dom_id={drawer_dom_id}>
        <main>
          {render_slot(@inner_block)}
        </main>
      </Drawer.render>
    </div>

    <Toast.toast_group flash={@flash} connection_toasts={true} theme="system" rich_colors={false} />
    """
  end

  attr :drawer_dom_id, :string, required: true

  def navbar(assigns) do
    ~H"""
    <div class="bg-base-300 items-center flex px-2 py-2 gap-3 border-b border-base-100">
      <label
        for={@drawer_dom_id}
        aria-label="open sidebar"
        class={[
          "hover:bg-base-100 transition",
          "cursor-pointer",
          "size-8 rounded",
          "flex items-center justify-center"
        ]}
      >
        <.icon name="hero-bars-3-micro is-drawer-close:hidden" />
      </label>

      <span class="grow">Berlin hikers</span>

      <Avatar.render user={@user} />
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
