defmodule LexWeb.PageLive.Navigation do
  use LexWeb, :live_view

  alias Ash.Error
  alias Ash.Error.Query.NotFound
  alias Lex.Accounts.Membership.Access
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageRevision
  alias Lex.Wiki.PageTitle
  alias LexWeb.PageLive.Creation
  alias LexWeb.PageLive.EditTitle
  alias LexWeb.PageLive.PageRepository
  alias LexWeb.PageLive.Revisions
  alias LexWeb.Router.Path
  alias Utils.Slugify

  @creation_title_flash "page_creation_title"

  def handle_params(socket, %{"page_slug" => slug} = params) do
    scope = socket.assigns.scope
    canonical_slug = slug |> Slugify.generate()

    cond do
      canonical_slug == "" ->
        raise NotFound, resource: Page, primary_key: %{slug: slug}

      canonical_slug != slug ->
        socket |> redirect_to_canonical_slug(scope, params, slug, canonical_slug)

      true ->
        socket |> load_page_from_slug(scope, slug, params)
    end
  end

  def load_page(socket, page, revision_number) do
    socket
    |> assign(page: page)
    |> EditTitle.reload(page)
    |> Revisions.reload(page, revision_number)
    |> PageRepository.reload()
  end

  def page_path(
        %{
          assigns: %{
            live_action: :revisions,
            revisions: %{
              requested_number: revision_number,
              selected: %PageRevision{}
            },
            scope: scope
          }
        },
        page
      )
      when revision_number != nil,
      do: Path.to(scope, page, revision_number)

  def page_path(
        %{assigns: %{live_action: :revisions, scope: scope}},
        page
      ),
      do: Path.revisions(scope, page)

  def page_path(%{assigns: %{scope: scope}}, page), do: Path.to(scope, page)

  defp redirect_to_canonical_slug(socket, scope, params, slug, canonical_slug) do
    path =
      case socket.assigns.live_action do
        :revisions -> scope |> Path.revisions(canonical_slug, params["revision_number"])
        _live_action -> scope |> Path.wiki(canonical_slug)
      end

    socket =
      case PageTitle.normalize(slug) do
        {:ok, title} -> socket |> put_flash(@creation_title_flash, title)
        {:error, _message} -> socket
      end

    socket = socket |> push_patch(to: path)

    {:noreply, socket}
  end

  defp load_page_from_slug(socket, scope, slug, params) do
    suggested_title = socket.assigns.flash |> Phoenix.Flash.get(@creation_title_flash)

    socket =
      if connected?(socket) do
        socket |> clear_flash(@creation_title_flash)
      else
        socket
      end

    scope
    |> Page.fetch_by_slug(slug)
    |> case do
      {:ok, nil} when slug == "home" ->
        socket =
          socket
          |> load_home_or_creation(scope, slug, suggested_title, params["revision_number"])

        {:noreply, socket}

      {:ok, nil} ->
        socket = socket |> load_creation(scope, slug, suggested_title)

        {:noreply, socket}

      {:ok, page} ->
        socket = socket |> load_page(page, params["revision_number"])

        {:noreply, socket}

      {:error, %Error.Invalid{}} ->
        raise NotFound, resource: Page, primary_key: %{slug: slug}

      {:error, error} ->
        raise error
    end
  end

  defp load_home_or_creation(socket, scope, slug, suggested_title, revision_number) do
    if scope |> Access.can?(:edit_pages) do
      page = scope |> Page.ensure!("Home")

      socket |> load_page(page, revision_number)
    else
      socket |> load_creation(scope, slug, suggested_title)
    end
  end

  defp load_creation(socket, scope, slug, suggested_title) do
    socket
    |> assign(page: nil)
    |> Creation.reload(scope, slug, suggested_title)
  end
end
