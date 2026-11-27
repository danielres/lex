defmodule LexWeb.PageLive.Creation do
  use LexWeb, :live_view
  use LiveDelegate, path: [:creation]

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageName
  alias LexWeb.Router.Path

  def on_mount(_params, _session, socket) do
    socket |> delegate_assign(%{form: nil, slug: nil})
  end

  def reload(socket, scope, slug, suggested_name) do
    name = suggested_name || PageName.from_slug(slug)
    form = if can?(scope, :edit_pages), do: scope |> creation_form(name)

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
    scope = socket.assigns.scope

    form
    |> AshPhoenix.Form.submit(params: params)
    |> case do
      {:ok, page} ->
        path = Path.to(scope, page)
        socket = socket |> push_navigate(to: path)

        {:noreply, socket}

      {:error, form} ->
        socket = socket |> delegate_assign(:form, form)

        {:noreply, socket}
    end
  end

  attr :creation, :map, required: true
  attr :scope, Lex.Scope, required: true

  @impl true
  def render(assigns) do
    path_preview =
      if assigns.creation.form do
        path_preview(assigns.creation.form[:name].value)
      end

    assigns = assigns |> assign(path_preview: path_preview)

    ~H"""
    <section class="mx-auto mt-16 max-w-2xs space-y-2 text-center" data-testid="missing-page">
      <div>
        <h1 class="text-xl font-semibold">This page doesn’t exist</h1>
        <p :if={can?(@scope, :edit_pages)} class="text-base-content/60">
          Choose a title to create a new page.
        </p>
        <p :if={!can?(@scope, :edit_pages)} class="text-base-content/60">
          You don’t have permission to create it.
        </p>
      </div>

      <.form
        :if={can?(@scope, :edit_pages)}
        for={@creation.form}
        id="page-creation-form"
        class="space-y-4"
        data-testid="page-creation-form"
        phx-change={delegate_event("validate")}
        phx-submit={delegate_event("create")}
      >
        <.input
          autocomplete="off"
          field={@creation.form[:name]}
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

  defp creation_form(scope, name) do
    Page
    |> AshPhoenix.Form.for_create(:create,
      as: "page",
      params: %{"name" => name},
      scope: scope
    )
    |> to_form()
  end

  defp path_preview(name) when is_binary(name) do
    if String.trim(name) == "" do
      nil
    else
      case PageName.slug(name) do
        {:ok, slug} -> "/wiki/#{slug}"
        {:error, _message} -> nil
      end
    end
  end

  defp path_preview(_name), do: nil
end
