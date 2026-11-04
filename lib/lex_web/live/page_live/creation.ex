defmodule LexWeb.PageLive.Creation do
  use LexWeb, :live_view
  use LiveDelegate, path: [:creation]

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageTitle

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{form: nil, slug: nil})
  end

  def reload(socket, scope, slug) do
    form = scope |> creation_form(slug)

    socket |> delegate_assign(%{form: form, slug: slug})
  end

  @impl true
  def handle_event("validate", %{"page" => params}, socket) do
    form = socket.assigns.creation.form
    form = form |> AshPhoenix.Form.validate(params)
    socket = socket |> delegate_assign(:form, form)

    {:noreply, socket}
  end

  def handle_event("create", %{"page" => params}, socket) do
    form = socket.assigns.creation.form
    space = socket.assigns.space

    form
    |> AshPhoenix.Form.submit(params: params)
    |> case do
      {:ok, page} ->
        path = ~p"/#{space.slug}/wiki/#{page.slug}"
        socket = socket |> push_navigate(to: path)

        {:noreply, socket}

      {:error, form} ->
        socket = socket |> delegate_assign(:form, form)

        {:noreply, socket}
    end
  end

  attr :creation, :map, required: true

  @impl true
  def render(assigns) do
    path_preview = path_preview(assigns.creation.form[:title].value)
    assigns = assigns |> assign(path_preview: path_preview)

    ~H"""
    <section class="mx-auto mt-16 max-w-2xs space-y-2 text-center" data-testid="missing-page">
      <div>
        <h1 class="text-xl font-semibold">This page doesn’t exist</h1>
        <p class="text-base-content/60">
          Choose a title to create a new page.
        </p>
      </div>

      <.form
        for={@creation.form}
        id="page-creation-form"
        class="space-y-4"
        data-testid="page-creation-form"
        phx-change={delegate_event("validate")}
        phx-submit={delegate_event("create")}
      >
        <.input
          autocomplete="off"
          field={@creation.form[:title]}
          placeholder="Page title"
          phx-hook="CapitalizeFirstLetter"
        />
        <div
          :if={@path_preview}
          class="text-sm text-base-content/50"
          data-testid="page-slug-preview"
        >
          {@path_preview}
        </div>
        <div class="flex justify-center">
          <button type="submit" class="btn btn-info">Create page</button>
        </div>
      </.form>
    </section>
    """
  end

  defp creation_form(scope, slug) do
    title = PageTitle.from_slug(slug)

    Page
    |> AshPhoenix.Form.for_create(:create,
      as: "page",
      params: %{"title" => title},
      scope: scope
    )
    |> to_form()
  end

  defp path_preview(title) when is_binary(title) do
    if String.trim(title) == "" do
      nil
    else
      case PageTitle.slug(title) do
        {:ok, slug} -> "/wiki/#{slug}"
        {:error, _message} -> nil
      end
    end
  end

  defp path_preview(_title), do: nil
end
