defmodule Lex.Topics.Changes.PruneGraph do
  alias Lex.Accounts.Space
  alias Lex.Scope
  alias Lex.Topics.Graph

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      topic = changeset.data

      with {:ok, space} <- Ash.get(Space, topic.space_id, actor: context.actor),
           scope = %Scope{user: context.actor, space: space},
           {:ok, _graph} <- Graph.remove_topic(topic.id, scope: scope) do
        changeset
      else
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    end)
  end
end
