defmodule AshAuthenticationDevelopment.Strategy do
  @moduledoc """
  An AshAuthentication strategy that signs in a configured development user.
  """

  alias AshAuthenticationDevelopment.Strategy.Transformer

  defstruct name: :development,
            identity: nil,
            users: [],
            resource: nil,
            sign_in_action_name: nil,
            __spark_metadata__: nil

  @entity %Spark.Dsl.Entity{
    name: :development,
    describe: "A development-only user picker authentication strategy.",
    target: __MODULE__,
    args: [{:optional, :name, :development}],
    schema: [
      name: [type: :atom, required: true],
      identity: [type: :atom, required: true],
      users: [type: :keyword_list, required: true]
    ]
  }

  use AshAuthentication.Strategy.Custom, entity: @entity

  @impl true
  def transform(strategy, dsl_state), do: Transformer.transform(strategy, dsl_state)
end
