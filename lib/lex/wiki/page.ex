defmodule Lex.Wiki.Page do
  require Ash.Query

  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.HasPrivilege
  alias Lex.Accounts.User
  alias Lex.Wiki.Page.Changes.SetTitleAndSlug
  alias Lex.Wiki.PageSlug
  alias Lex.Wiki.PageTitle

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "pages"
    repo Lex.Repo
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :list, action: :list
    define :rename, action: :rename, args: [:title]
  end

  actions do
    defaults [:read]

    read :list do
      prepare build(load: [:author, :last_updated_at], sort: :title)
    end

    create :create do
      accept [:title]

      change relate_actor(:author)
      change SetTitleAndSlug
    end

    update :rename do
      accept [:title]
      require_atomic? false

      change SetTitleAndSlug
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action([:create, :rename]) do
      authorize_if {HasPrivilege, privilege: :edit_pages}
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :create, "pages"
    publish :rename, "pages"
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, Lex.Wiki.PageSlug do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, User do
      allow_nil? false
    end

    belongs_to :space, Lex.Accounts.Space do
      destination_attribute :id
      allow_nil? false
    end
  end

  calculations do
    calculate :last_updated_at,
              :utc_datetime_usec,
              expr(
                fragment(
                  "GREATEST(?, COALESCE((SELECT MAX(updated_at) FROM page_documents WHERE page_id = ?), ?))",
                  updated_at,
                  id,
                  updated_at
                )
              )
  end

  identities do
    identity :unique_slug, [:slug],
      eager_check?: true,
      field_names: [:title],
      message: "Not available"
  end

  def ensure(scope, title) do
    with {:ok, title} <- PageTitle.normalize(title),
         {:ok, slug} <- PageTitle.slug(title) do
      scope |> ensure_title_and_slug(title, slug)
    else
      {:error, message} -> invalid_attribute(:title, title, message)
    end
  end

  def ensure!(scope, title) do
    scope
    |> ensure(title)
    |> case do
      {:ok, page} -> page
      {:error, error} -> raise Ash.Error.to_error_class(error)
    end
  end

  def fetch_by_slug(scope, slug) do
    with true <- PageSlug.valid?(slug),
         {:ok, slug} <- Ash.Type.cast_input(PageSlug, slug) do
      scope |> get_by_slug(slug)
    else
      false -> invalid_attribute(:slug, slug, "is not a valid page slug")
      :error -> invalid_attribute(:slug, slug, "is not a valid page slug")
      {:error, error} -> {:error, error}
    end
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Lex.PubSub, "wiki:pages")
  end

  defp ensure_title_and_slug(scope, title, slug) do
    scope
    |> get_by_slug(slug)
    |> case do
      {:ok, nil} -> scope |> create_page(title, slug)
      {:ok, %{title: ^title} = page} -> {:ok, page}
      {:ok, _page} -> title_collision(title, slug)
      {:error, error} -> {:error, error}
    end
  end

  defp create_page(scope, title, slug) do
    __MODULE__
    |> Ash.Changeset.for_create(:create, %{title: title}, scope: scope)
    |> Ash.create()
    |> recover_concurrent_create(scope, title, slug)
  end

  defp recover_concurrent_create({:ok, page}, _scope, _title, _slug), do: {:ok, page}

  defp recover_concurrent_create({:error, original_error}, scope, title, slug) do
    scope
    |> get_by_slug(slug)
    |> case do
      {:ok, %{title: ^title} = page} -> {:ok, page}
      {:ok, nil} -> {:error, original_error}
      {:ok, _page} -> title_collision(title, slug)
      {:error, _error} -> {:error, original_error}
    end
  end

  defp get_by_slug(scope, slug) do
    __MODULE__
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.Query.load(:author)
    |> Ash.read_one(scope: scope)
  end

  defp title_collision(title, slug) do
    invalid_attribute(
      :title,
      title,
      "produces the already-used slug #{inspect(slug)}"
    )
  end

  defp invalid_attribute(field, value, message) do
    error =
      Ash.Error.Changes.InvalidAttribute.exception(
        field: field,
        value: value,
        message: message
      )

    {:error, Ash.Error.to_error_class(error)}
  end
end
