defmodule LexWeb.Router.Path do
  use LexWeb, :verified_routes

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space
  alias Lex.Scope
  alias Lex.Topics.Topic

  def to(%Space{} = space) do
    ~p"/#{space.slug}"
  end

  def to(%Scope{} = scope, %Topic{} = topic) do
    ~p"/#{scope.space.slug}/topics/#{topic.slug}"
  end

  def to(%Scope{} = scope, %Membership{} = membership) do
    ~p"/#{scope.space.slug}/members/#{membership.slug}"
  end

  def spaces do
    "/"
  end

  def sign_in do
    # TODO: redirect to non-dev route outside of dev
    "/dev/auth/sign-in"
  end

  def onboarding(%Space{} = space) do
    ~p"/#{space.slug}/onboarding"
  end

  def topics(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/topics"
  end

  def members(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/members"
  end
end
