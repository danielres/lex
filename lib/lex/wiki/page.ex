defmodule Lex.Wiki.Page do
  require Ash.Query

  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.HasPrivilege
  alias Lex.Accounts.User
  alias Lex.Wiki.Page.Changes.SetNameAndSlug
  alias Lex.Wiki.PageSlug
  alias Lex.Wiki.PageName

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
    define :rename, action: :rename, args: [:name]
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(load: [:author, :last_updated_at], sort: :name)
    end

    create :create do
      accept [:name]

      change relate_actor(:author)
      change SetNameAndSlug
    end

    update :rename do
      accept [:name]
      require_atomic? false

      change SetNameAndSlug
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action([:create, :rename]) do
      authorize_if {HasPrivilege, privilege: :edit_pages}
    end

    policy action(:destroy) do
      forbid_if expr(slug == "home")
      authorize_if {HasPrivilege, privilege: :edit_pages}
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :create, "pages"
    publish :rename, "pages"
    publish :destroy, "pages"
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
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
      field_names: [:name],
      message: "Not available"
  end

  def ensure(scope, name) do
    with {:ok, name} <- PageName.normalize(name),
         {:ok, slug} <- PageName.slug(name) do
      scope |> ensure_name_and_slug(name, slug)
    else
      {:error, message} -> invalid_attribute(:name, name, message)
    end
  end

  def ensure!(scope, name) do
    scope
    |> ensure(name)
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

  defp ensure_name_and_slug(scope, name, slug) do
    scope
    |> get_by_slug(slug)
    |> case do
      {:ok, nil} -> scope |> create_page(name, slug)
      {:ok, %{name: ^name} = page} -> {:ok, page}
      {:ok, _page} -> name_collision(name, slug)
      {:error, error} -> {:error, error}
    end
  end

  defp create_page(scope, name, slug) do
    __MODULE__
    |> Ash.Changeset.for_create(:create, %{name: name}, scope: scope)
    |> Ash.create()
    |> recover_concurrent_create(scope, name, slug)
  end

  defp recover_concurrent_create({:ok, page}, _scope, _name, _slug), do: {:ok, page}

  defp recover_concurrent_create({:error, original_error}, scope, name, slug) do
    scope
    |> get_by_slug(slug)
    |> case do
      {:ok, %{name: ^name} = page} -> {:ok, page}
      {:ok, nil} -> {:error, original_error}
      {:ok, _page} -> name_collision(name, slug)
      {:error, _error} -> {:error, original_error}
    end
  end

  defp get_by_slug(scope, slug) do
    __MODULE__
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.Query.load(:author)
    |> Ash.read_one(scope: scope)
  end

  defp name_collision(name, slug) do
    invalid_attribute(
      :name,
      name,
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
