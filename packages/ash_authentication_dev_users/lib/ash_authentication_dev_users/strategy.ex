defmodule AshAuthenticationDevUsers.Strategy do
  @moduledoc """
  An AshAuthentication strategy that signs in a configured development user.
  """

  alias AshAuthenticationDevUsers.Strategy.Transformer

  defstruct name: :dev_users,
            identity: nil,
            users: [],
            resource: nil,
            sign_in_action_name: nil,
            __spark_metadata__: nil

  @entity %Spark.Dsl.Entity{
    name: :dev_users,
    describe: "A configured development-user authentication strategy.",
    target: __MODULE__,
    auto_set_fields: [name: :dev_users],
    schema: [
      identity: [type: :atom, required: true],
      users: [type: :keyword_list, required: true]
    ]
  }

  use AshAuthentication.Strategy.Custom, entity: @entity

  @impl true
  def transform(strategy, dsl_state), do: Transformer.transform(strategy, dsl_state)
end
