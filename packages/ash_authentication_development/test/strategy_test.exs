defmodule AshAuthenticationDevelopment.StrategyTest do
  use ExUnit.Case, async: false

  alias AshAuthentication.Strategy
  alias AshAuthenticationDevelopment.Test.User

  setup do
    previous = Application.get_env(:ash_authentication_development, :enabled)
    Application.put_env(:ash_authentication_development, :enabled, true)

    on_exit(fn ->
      Application.put_env(:ash_authentication_development, :enabled, previous)
    end)

    strategy = AshAuthentication.Info.strategy!(User, :development)
    {:ok, strategy: strategy}
  end

  test "exposes configured users in display order", %{strategy: strategy} do
    assert AshAuthenticationDevelopment.users(User) == [
             tom: %{name: "Tom", hue: 25},
             sandra: %{name: "Sandra", hue: 115}
           ]

    assert Strategy.phases(strategy) == [:sign_in]
    assert Strategy.method_for_phase(strategy, :sign_in) == :post
    assert Strategy.routes(strategy) == [{"/user/development/sign_in", :sign_in}]
    assert Strategy.tokens_required?(strategy)
  end

  test "provisions and reuses configured users", %{strategy: strategy} do
    existing_user = Ash.Seed.seed!(User, %{name: "Tom", hue: 0})

    assert {:ok, first_user} = Strategy.action(strategy, :sign_in, %{"user" => "tom"})
    assert first_user.id == existing_user.id
    assert first_user.name == "Tom"
    assert first_user.hue == 25
    assert is_binary(first_user.__metadata__.token)

    assert {:ok, second_user} = Strategy.action(strategy, :sign_in, %{"user" => "tom"})
    assert second_user.id == first_user.id
    assert [_user] = Ash.read!(User, authorize?: false)
  end

  test "rejects unknown users", %{strategy: strategy} do
    assert {:error, %AshAuthentication.Errors.AuthenticationFailed{}} =
             Strategy.action(strategy, :sign_in, %{"user" => "mallory"})

    assert Ash.read!(User, authorize?: false) == []
  end

  test "rejects authentication when disabled", %{strategy: strategy} do
    Application.put_env(:ash_authentication_development, :enabled, false)

    assert {:error, %AshAuthentication.Errors.AuthenticationFailed{}} =
             Strategy.action(strategy, :sign_in, %{"user" => "tom"})

    assert Ash.read!(User, authorize?: false) == []
  end
end
