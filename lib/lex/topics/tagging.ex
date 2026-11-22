defmodule Lex.Topics.Tagging do
  alias Lex.Accounts
  alias Lex.Accounts.Membership
  alias Lex.Topics.Tagging.Presenter
  alias Lex.Topics.Topic

  use Ash.Resource,
    otp_app: :lex,
    domain: Lex.Topics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  require Ash.Query

  postgres do
    table "topic_taggings"
    repo Lex.Repo

    references do
      reference :tagged_by_membership, on_delete: :delete
      reference :topic, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :dimensions,
        :taggable_id,
        :taggable_type,
        :tagged_by_membership_id,
        :text,
        :topic_id
      ]

      primary? true
    end

    update :update do
      accept [:dimensions, :text]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:space, :members])
    end

    policy action(:create) do
      authorize_if relates_to_actor_via([:tagged_by_membership, :user])
    end

    policy action(:update) do
      authorize_if relates_to_actor_via([:tagged_by_membership, :user])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:tagged_by_membership, :user])
      authorize_if relates_to_actor_via([:tagged_membership, :user])
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "topics"

    publish :create, ["taggings", :taggable_type, :taggable_id]
    publish :destroy, ["taggings", :taggable_type, :taggable_id]
    publish :update, ["taggings", :taggable_type, :taggable_id]
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_primary_key :id

    attribute :taggable_type, :string, allow_nil?: false
    attribute :taggable_id, :uuid, allow_nil?: false
    attribute :dimensions, :map, allow_nil?: false
    attribute :text, :string

    timestamps()
  end

  relationships do
    belongs_to :space, Accounts.Space, allow_nil?: false
    belongs_to :tagged_by_membership, Membership, allow_nil?: false
    belongs_to :topic, Topic, allow_nil?: false

    has_one :tagged_membership, Membership do
      source_attribute :taggable_id
      destination_attribute :id
      filter expr(parent(taggable_type) == "membership")
    end
  end

  identities do
    identity :unique_tagging,
             [
               :space_id,
               :taggable_type,
               :taggable_id,
               :tagged_by_membership_id,
               :topic_id
             ]
  end

  def for_target(target, opts) do
    scope = Keyword.fetch!(opts, :scope)
    {taggable_type, taggable_id} = target_ref(target)

    __MODULE__
    |> Ash.Query.filter(taggable_type == ^taggable_type and taggable_id == ^taggable_id)
    |> Ash.Query.load([:topic, :tagged_by_membership])
    |> Ash.read(scope: scope)
  end

  def present_for_target(target, sorting, opts) do
    with {:ok, taggings} <- for_target(target, opts) do
      {:ok, Presenter.present(taggings, target, sorting)}
    end
  end

  def set(target, topic, tagged_by_membership, content, opts) do
    dimensions = dimensions_for(target, tagged_by_membership, content.dimensions)
    text = normalize_text(content.text)

    if empty?(target, tagged_by_membership, dimensions, text) do
      with {:ok, _tagging} <- remove(target, topic, tagged_by_membership, opts) do
        {:ok, nil}
      end
    else
      persist(target, topic, tagged_by_membership, dimensions, text, opts)
    end
  end

  def remove(tagging, opts) do
    scope = Keyword.fetch!(opts, :scope)

    case Ash.destroy(tagging, scope: scope) do
      :ok -> {:ok, tagging}
      {:error, error} -> {:error, error}
    end
  end

  def remove(target, topic, tagged_by_membership, opts) do
    scope = Keyword.fetch!(opts, :scope)

    case get_with_scope(target, topic, tagged_by_membership, scope) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, tagging} ->
        remove(tagging, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  def get(target, topic, tagged_by_membership, opts) do
    scope = Keyword.fetch!(opts, :scope)
    get_with_scope(target, topic, tagged_by_membership, scope)
  end

  def pub_sub_topic(target) do
    {taggable_type, taggable_id} = target_ref(target)
    "topics:taggings:#{taggable_type}:#{taggable_id}"
  end

  defp persist(target, topic, tagged_by_membership, dimensions, text, opts) do
    scope = Keyword.fetch!(opts, :scope)

    case get_with_scope(target, topic, tagged_by_membership, scope) do
      {:ok, nil} ->
        {taggable_type, taggable_id} = target_ref(target)

        __MODULE__
        |> Ash.Changeset.for_create(
          :create,
          %{
            dimensions: dimensions,
            taggable_id: taggable_id,
            taggable_type: taggable_type,
            tagged_by_membership_id: tagged_by_membership.id,
            text: text,
            topic_id: topic.id
          },
          scope: scope
        )
        |> Ash.create()

      {:ok, tagging} ->
        tagging
        |> Ash.Changeset.for_update(
          :update,
          %{dimensions: dimensions, text: text},
          scope: scope
        )
        |> Ash.update()

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_with_scope(target, topic, tagged_by_membership, scope) do
    {taggable_type, taggable_id} = target_ref(target)

    __MODULE__
    |> Ash.Query.filter(
      taggable_type == ^taggable_type and
        taggable_id == ^taggable_id and
        tagged_by_membership_id == ^tagged_by_membership.id and
        topic_id == ^topic.id
    )
    |> Ash.read_one(scope: scope)
  end

  defp target_ref(%Membership{id: id}), do: {"membership", id}

  defp dimensions_for(%Membership{} = target, %Membership{} = tagged_by, dimensions) do
    if target.id == tagged_by.id do
      dimensions
      |> Enum.reject(fn {_key, value} -> value in [0, nil] end)
      |> Map.new()
    else
      %{}
    end
  end

  defp empty?(%Membership{} = target, %Membership{} = tagged_by, dimensions, text) do
    if target.id == tagged_by.id do
      dimensions == %{}
    else
      is_nil(text)
    end
  end

  defp normalize_text(text) do
    case String.trim(text || "") do
      "" -> nil
      text -> text
    end
  end
end
