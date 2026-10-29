defmodule LexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LexWeb, :html

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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.drawer {assigns}>
      <main>
        {render_slot(@inner_block)}
      </main>
    </.drawer>

    <Toast.toast_group flash={@flash} connection_toasts={true} theme="system" rich_colors={false} />
    <%!-- <Toast.flash_group flash={@flash} /> --%>
    """
  end

  def drawer(assigns) do
    ~H"""
    <% active_class = "bg-info text-white" %>
    <div class="min-h-svh grid grid-rows-[auto_1fr]">
      <div class="bg-base-300 items-center flex px-3 py-2 gap-2 border-b border-base-100">
        <label
          for="my-drawer-4"
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
        <span class="">Navbar</span>
      </div>

      <div class="drawer sm:drawer-open">
        <input id="my-drawer-4" type="checkbox" class="drawer-toggle inline" />
        <div class="drawer-content p-4 sm:px-8">
          <!-- Page content here -->
          {render_slot(@inner_block)}
        </div>

        <div class="drawer-side is-drawer-close:overflow-visible h-auto">
          <label for="my-drawer-4" aria-label="close sidebar" class="drawer-overlay"></label>
          <div class={[
            "flex min-h-full flex-col items-start bg-base-300/50 backdrop-blur",
            "is-drawer-close:w-15 px-1 is-drawer-open:w-40 pr-3",
            "border-r border-base-100",
            "max-sm:min-h-svh",
            "py-4"
          ]}>
            <!-- Sidebar content here -->
            <ul class={[
              "grid gap-2 w-full font-semibold",
              "[&_a]:h-8",
              "[&_li]:ml-2",
              "[&_a]:is-drawer-close:aspect-square",
              "[&_a]:is-drawer-open:px-2",
              "[&_a]:flex",
              "[&_a]:items-center",
              "[&_a]:gap-2",
              "[&_a]:is-drawer-close:justify-center",
              "[&_a]:rounded",
              "[&_a]:text-sm"
            ]}>
              <li>
                <.link
                  navigate={~p"/"}
                  class={[
                    "is-drawer-close:tooltip is-drawer-close:tooltip-right",
                    @active == "dashboard" && active_class
                  ]}
                  data-tip="Dashboard"
                >
                  <.icon name="hero-squares-2x2-solid" />
                  <span class="is-drawer-close:hidden">Dashboard</span>
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/wiki/home"}
                  class={[
                    "is-drawer-close:tooltip is-drawer-close:tooltip-right",
                    @active == "page" && active_class,
                    @active == "wiki" && active_class
                  ]}
                  data-tip="Wiki"
                >
                  <.icon name="hero-book-open-mini" />
                  <span class="is-drawer-close:hidden">Wiki</span>
                </.link>
              </li>
            </ul>

            <div class={[
              "border-t border-base-100 py-2 mt-2",
              "w-full flex justify-center",
              "is-drawer-close:hidden"
            ]}>
              <.theme_toggle />
            </div>
          </div>
        </div>
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

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
