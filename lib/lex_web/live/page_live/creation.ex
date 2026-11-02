defmodule LexWeb.PageLive.Creation do
  use LexWeb, :live_view
  use LiveDelegate, path: [:creation]

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageTitle

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{form: creation_form(), slug: nil})
  end

  def reload(socket, slug) do
    delegate_assign(socket, %{form: creation_form(slug), slug: slug})
  end

  @impl true
  def handle_event("validate", %{"page" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.creation.form, params)
    {:noreply, delegate_assign(socket, :form, form)}
  end

  def handle_event("create", %{"page" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.creation.form, params: params) do
      {:ok, page} ->
        {:noreply, push_navigate(socket, to: ~p"/#{socket.assigns.space.slug}/wiki/#{page.slug}")}

      {:error, form} ->
        {:noreply, delegate_assign(socket, :form, form)}
    end
  end

  attr :creation, :map, required: true

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :path_preview, path_preview(assigns.creation.form[:title].value))

    ~H"""
    <section class="mx-auto mt-16 max-w-2xs space-y-2 text-center" data-testid="missing-page">
      <div class="">
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

  defp creation_form do
    Page
    |> AshPhoenix.Form.for_create(:create, as: "page")
    |> to_form()
  end

  defp creation_form(slug) do
    Page
    |> AshPhoenix.Form.for_create(:create,
      as: "page",
      params: %{"title" => PageTitle.from_slug(slug)}
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
