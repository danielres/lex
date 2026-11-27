defmodule Lex.Wiki.PageRevision do
  @moduledoc false

  require Ash.Query

  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.HasPrivilege
  alias Lex.Validations.RelationshipInSpace
  alias Lex.Wiki.PageRevision.Changes.SetNumber

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "page_revisions"
    repo Lex.Repo

    references do
      reference :page, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      argument :contributor_ids, {:array, :uuid} do
        allow_nil? false
        default []
      end

      accept [
        :content_hash,
        :lexical_state,
        :page_id,
        :restored_from_revision_id,
        :search_text
      ]

      change SetNumber
      change relate_actor(:saved_by)
      change manage_relationship(:contributor_ids, :contributors, type: :append)
      validate {RelationshipInSpace, relationship: :page}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action(:create) do
      authorize_if {HasPrivilege, privilege: :edit_pages}
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :create, "pages"
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :content_hash, :string do
      allow_nil? false
      constraints min_length: 64, max_length: 64
      public? true
    end

    attribute :lexical_state, :map do
      allow_nil? false
      public? true
    end

    attribute :number, :integer do
      allow_nil? false
      constraints min: 1
      public? true
    end

    attribute :restored_from_revision_id, :uuid do
      public? true
    end

    attribute :search_text, :string do
      allow_nil? false
      constraints allow_empty?: true
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :saved_by, Lex.Accounts.User do
      allow_nil? false
    end

    belongs_to :page, Lex.Wiki.Page do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :space, Lex.Accounts.Space do
      allow_nil? false
    end

    many_to_many :contributors, Lex.Accounts.User do
      through Lex.Wiki.PageRevisionContributor
      source_attribute_on_join_resource :page_revision_id
      destination_attribute_on_join_resource :user_id
      sort display_name: :asc
    end
  end

  identities do
    identity :unique_page_number, [:page_id, :number]
  end

  def list!(scope, page) do
    __MODULE__
    |> Ash.Query.filter(page_id == ^page.id)
    |> Ash.Query.load([:saved_by, :contributors])
    |> Ash.Query.sort(number: :desc)
    |> Ash.read!(scope: scope)
  end

  def selection!(scope, page, requested_number) do
    query = __MODULE__ |> Ash.Query.filter(page_id == ^page.id)
    latest_number = query |> Ash.max!(:number, scope: scope)
    selected_number = requested_number || latest_number
    previous_number = if selected_number, do: selected_number - 1

    numbers =
      [selected_number, previous_number]
      |> Enum.filter(&is_integer/1)
      |> Enum.filter(&(&1 > 0))

    revisions =
      query
      |> Ash.Query.filter(number in ^numbers)
      |> Ash.Query.load([:saved_by, :contributors])
      |> Ash.read!(scope: scope)

    selected = Enum.find(revisions, &(&1.number == selected_number))
    previous = Enum.find(revisions, &(&1.number == previous_number))

    if selected_number != nil and selected == nil do
      raise Ash.Error.Query.NotFound,
        resource: __MODULE__,
        primary_key: %{number: selected_number}
    end

    previous_lexical_state = if previous, do: previous.lexical_state

    %{
      latest_number: latest_number,
      previous_lexical_state: previous_lexical_state,
      selected: selected,
      selected_number: selected_number
    }
  end

  def get(scope, page, revision_id) do
    __MODULE__
    |> Ash.Query.filter(page_id == ^page.id and id == ^revision_id)
    |> Ash.read_one(scope: scope)
  end

  def record(
        scope,
        page,
        %{lexical_state: lexical_state, search_text: search_text} = content,
        restored_from_revision_id
      ) do
    content_hash = content_hash(lexical_state)
    contributor_ids = Map.get(content, :contributor_ids, [])

    with :ok <- scope |> validate_source(page, restored_from_revision_id),
         {:ok, latest_revision} <- scope |> latest(page) do
      if latest_revision != nil and latest_revision.content_hash == content_hash do
        {:ok, :unchanged}
      else
        scope
        |> create(
          page,
          lexical_state,
          search_text,
          content_hash,
          restored_from_revision_id,
          contributor_ids
        )
        |> case do
          {:ok, _revision} -> {:ok, :saved}
          {:error, error} -> {:error, error}
        end
      end
    end
  end

  defp latest(scope, page) do
    __MODULE__
    |> Ash.Query.filter(page_id == ^page.id)
    |> Ash.Query.sort(number: :desc)
    |> Ash.read_first(scope: scope)
  end

  defp validate_source(_scope, _page, nil), do: :ok

  defp validate_source(scope, page, revision_id) do
    scope
    |> get(page, revision_id)
    |> case do
      {:ok, nil} -> invalid_source(revision_id)
      {:ok, _revision} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp invalid_source(revision_id) do
    error =
      Ash.Error.Changes.InvalidAttribute.exception(
        field: :restored_from_revision_id,
        value: revision_id,
        message: "does not exist"
      )

    {:error, Ash.Error.to_error_class(error)}
  end

  defp create(
         scope,
         page,
         lexical_state,
         search_text,
         content_hash,
         restored_from_revision_id,
         contributor_ids
       ) do
    __MODULE__
    |> Ash.Changeset.for_create(
      :create,
      %{
        contributor_ids: contributor_ids,
        content_hash: content_hash,
        lexical_state: lexical_state,
        page_id: page.id,
        restored_from_revision_id: restored_from_revision_id,
        search_text: search_text
      },
      scope: scope
    )
    |> Ash.create()
  end

  defp content_hash(lexical_state) do
    lexical_state
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
