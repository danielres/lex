defmodule LexWeb.Router.Path do
  use LexWeb, :verified_routes

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space
  alias Lex.Scope
  alias Lex.Topics.Topic
  alias Lex.Wiki.Page

  def to(%Space{} = space) do
    ~p"/#{space.slug}"
  end

  def to(%Scope{} = scope, %Membership{} = membership) do
    ~p"/#{scope.space.slug}/members/#{membership.slug}"
  end

  def to(%Scope{} = scope, %Topic{} = topic) do
    ~p"/#{scope.space.slug}/topics/#{topic.slug}"
  end

  def to(%Scope{} = scope, %Page{} = page) do
    ~p"/#{scope.space.slug}/wiki/#{page.slug}"
  end

  def to(%Scope{} = scope, %Page{} = page, revision_number)
      when is_integer(revision_number) do
    ~p"/#{scope.space.slug}/wiki/#{page.slug}/revisions/#{revision_number}"
  end

  def spaces, do: ~p"/"
  def sign_in, do: ~p"/sign-in"
  def dev_sign_in, do: ~p"/dev/auth/sign-in"
  def sign_out, do: ~p"/sign-out"

  def onboarding(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/join"
  end

  def revisions(%Scope{} = scope, %Page{} = page) do
    ~p"/#{scope.space.slug}/wiki/#{page.slug}/revisions"
  end

  def topics(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/topics"
  end

  def members(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/members"
  end

  def wiki(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/wiki"
  end

  def wiki(%Scope{} = scope, page_slug) do
    ~p"/#{scope.space.slug}/wiki/#{page_slug}"
  end

  def revisions(%Scope{} = scope, page_slug, nil) do
    ~p"/#{scope.space.slug}/wiki/#{page_slug}/revisions"
  end

  def revisions(%Scope{} = scope, page_slug, revision_number) do
    ~p"/#{scope.space.slug}/wiki/#{page_slug}/revisions/#{revision_number}"
  end

  def wiki_home(%Scope{} = scope) do
    ~p"/#{scope.space.slug}/wiki/home"
  end
end
