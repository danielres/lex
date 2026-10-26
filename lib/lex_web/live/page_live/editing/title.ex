defmodule LexWeb.PageLive.Editing.Title do
  use LexWeb, :html
  use LiveDelegate, path: [:editing]

  def render(assigns) do
    ~H"""
    <h1
      :if={@live_action != :editing || @page.slug == "home"}
      class={[
        "text-3xl opacity-80",
        "self-end",
        "leading-tight"
      ]}
    >
      {@page.title}
    </h1>

    <.form
      :if={@live_action == :editing && @page.slug != "home"}
      for={@editing.title_form}
      id="page-title-form"
      phx-change={delegate_event("title_change")}
      phx-hook=".PageTitleForm"
      phx-submit={delegate_event("title_save")}
      tabindex="-1"
      class="grow max-w-sm"
    >
      <div class={[
        "group join w-full rounded-box border border-base-100",
        "bg-base-200",
        "focus-within:border-info"
      ]}>
        <input
          aria-label="Page title"
          autocomplete="off"
          class={[
            "peer join-item grow",
            "w-full rounded-l-box px-2",
            "text-2xl opacity-75",
            "outline-none"
          ]}
          id={@editing.title_form[:title].id}
          name={@editing.title_form[:title].name}
          phx-hook="CapitalizeFirstLetter"
          phx-blur={reset_page_title()}
          phx-key="Escape"
          phx-keydown={reset_page_title()}
          value={@editing.title_form[:title].value}
        />
        <button
          aria-label="Cancel title change"
          class={[
            "opacity-0 group-focus-within:opacity-100 transition",
            "join-item btn btn-square btn-ghost",
            "bg-transparent"
          ]}
          phx-click={reset_page_title()}
          type="button"
        >
          <.icon name="hero-x-mark-micro" />
        </button>
        <button
          aria-label="Save page title"
          class={[
            "opacity-0 group-focus-within:opacity-100 transition",
            "join-item btn btn-square rounded-r-box",
            "btn-info"
          ]}
          type="submit"
        >
          <.icon name="hero-check-micro" />
        </button>
      </div>
      <p
        :for={{message, _options} <- @editing.title_form[:title].errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-error"
      >
        <.icon name="hero-exclamation-circle" class="size-5" />
        {message}
      </p>
    </.form>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PageTitleForm">
      export default {
        mounted() {
          this.handleSubmit = () => this.el.querySelector("input")?.blur()
          this.el.addEventListener("submit", this.handleSubmit)
          this.handleEvent("page_title_blur", () => this.el.querySelector("input")?.blur())
        },

        destroyed() {
          this.el.removeEventListener("submit", this.handleSubmit)
        },
      }
    </script>
    """
  end

  defp reset_page_title do
    JS.push(delegate_event("title_reset"))
    |> JS.focus(to: "#page-title-form")
  end
end
