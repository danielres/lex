defmodule Lex.Wiki.PageTest do
  use Lex.DataCase

  alias Lex.Wiki.Page

  setup do
    {:ok, scope: create_scope()}
  end

  describe "ensure/2" do
    test "creates a page with a slug derived from its title", %{scope: scope} do
      assert {:ok, page} = scope |> Page.ensure("Summer Activities")

      assert page.author.id == scope.current_user.id
      assert page.author_id == scope.current_user.id
      assert page.title == "Summer Activities"
      assert page.slug == "summer-activities"
      assert {:ok, page.id} == Ecto.UUID.cast(page.id)
    end

    test "requires an actor when creating a page", %{scope: scope} do
      result =
        Page
        |> Ash.Changeset.for_create(:create, %{title: "Summer Activities"},
          tenant: scope.space_id
        )
        |> Ash.create()

      assert {:error, error} = result
      assert Exception.message(error) =~ "could not relate to actor"
    end

    test "does not accept an author from page input", %{scope: scope} do
      changeset =
        Page
        |> Ash.Changeset.for_create(
          :create,
          %{author_id: create_user("Other User").id, title: "Summer Activities"},
          scope: scope
        )

      refute changeset.valid?
      assert [%Ash.Error.Invalid.NoSuchInput{input: :author_id}] = changeset.errors
    end

    test "publishes a notification after creating a page", %{scope: scope} do
      Page.subscribe()

      page = scope |> Page.ensure!("Summer Activities")

      assert_receive %Ash.Notifier.Notification{
        resource: Page,
        action: %{name: :create},
        data: %{id: page_id, title: "Summer Activities"}
      }

      assert page_id == page.id
    end

    test "returns the existing page for the same normalized title", %{scope: scope} do
      assert {:ok, first_page} = scope |> Page.ensure("Summer   Activities")
      assert {:ok, second_page} = scope |> Page.ensure("  Summer Activities ")

      assert second_page.id == first_page.id
      assert length(Ash.read!(Page, scope: scope)) == 1
    end

    test "preserves unicode letters in slugs", %{scope: scope} do
      assert {:ok, page} = scope |> Page.ensure("Café Ideas")

      assert page.slug == "café-ideas"
    end

    test "creates different pages for different titles", %{scope: scope} do
      assert {:ok, home} = scope |> Page.ensure("Home")
      assert {:ok, summer_activities} = scope |> Page.ensure("Summer Activities")

      refute summer_activities.id == home.id
    end

    test "rejects blank titles", %{scope: scope} do
      assert {:error, _error} = scope |> Page.ensure("   ")

      assert Ash.read!(Page, scope: scope) == []
    end

    test "rejects a different title that produces an existing slug", %{scope: scope} do
      scope |> Page.ensure!("Summer Activities")

      assert {:error, _error} = scope |> Page.ensure("Summer—Activities")
      assert length(Ash.read!(Page, scope: scope)) == 1
    end

    test "concurrent calls converge on one page", %{scope: scope} do
      pages =
        1..10
        |> Task.async_stream(
          fn _ -> scope |> Page.ensure!("Shared Page") end,
          max_concurrency: 10,
          ordered: false,
          timeout: 10_000
        )
        |> Enum.map(fn {:ok, page} -> page end)

      assert pages |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 1
      assert length(Ash.read!(Page, scope: scope)) == 1
    end
  end

  describe "fetch_by_slug/2" do
    test "returns nil for a valid slug that does not exist", %{scope: scope} do
      assert {:ok, nil} = scope |> Page.fetch_by_slug("summer-activities")
      assert Ash.read!(Page, scope: scope) == []
    end

    test "returns an existing page", %{scope: scope} do
      page = scope |> Page.ensure!("Summer Activities")

      assert {:ok, fetched_page} = scope |> Page.fetch_by_slug("summer-activities")
      assert fetched_page.id == page.id
    end

    test "rejects invalid route slugs", %{scope: scope} do
      assert {:error, _error} = scope |> Page.fetch_by_slug("Summer Activities")
    end
  end

  describe "rename/2" do
    test "changes the title and slug without changing the page id", %{scope: scope} do
      page = scope |> Page.ensure!("Summer Activities")

      renamed_page = Page.rename!(page, "  Winter   Activities ", scope: scope)

      assert renamed_page.id == page.id
      assert renamed_page.author.id == scope.current_user.id
      assert renamed_page.author_id == page.author_id
      assert renamed_page.title == "Winter Activities"
      assert renamed_page.slug == "winter-activities"
    end

    test "rejects a slug collision", %{scope: scope} do
      scope |> Page.ensure!("Winter Activities")
      summer = scope |> Page.ensure!("Summer Activities")

      assert {:error, _error} = Page.rename(summer, "Winter Activities", scope: scope)
      assert Page.get!(summer.id, scope: scope).slug == "summer-activities"
    end

    test "publishes a notification after a successful rename", %{scope: scope} do
      page = scope |> Page.ensure!("Summer Activities")
      Page.subscribe()

      renamed_page = Page.rename!(page, "Winter Activities", scope: scope)

      assert_receive %Ash.Notifier.Notification{
        resource: Page,
        action: %{name: :rename},
        data: %{id: page_id, title: "Winter Activities"}
      }

      assert page_id == renamed_page.id
    end
  end

  describe "list/1" do
    test "returns all pages sorted by title", %{scope: scope} do
      scope |> Page.ensure!("Summer Activities")
      scope |> Page.ensure!("Home")
      scope |> Page.ensure!("About")

      assert Page.list!(scope: scope) |> Enum.map(& &1.title) == [
               "About",
               "Home",
               "Summer Activities"
             ]
    end

    test "loads each page author", %{scope: scope} do
      scope |> Page.ensure!("Home")

      assert [%{author: author}] = Page.list!(scope: scope)
      assert author.id == scope.current_user.id
    end
  end
end
