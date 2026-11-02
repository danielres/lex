defmodule Lex.Wiki.PageTest do
  use Lex.DataCase

  alias Lex.Wiki.Page

  describe "ensure/1" do
    test "creates a page with a slug derived from its title" do
      assert {:ok, page} = Page.ensure("Summer Activities")

      assert page.title == "Summer Activities"
      assert page.slug == "summer-activities"
      assert {:ok, page.id} == Ecto.UUID.cast(page.id)
    end

    test "publishes a notification after creating a page" do
      Page.subscribe()

      page = Page.ensure!("Summer Activities")

      assert_receive %Ash.Notifier.Notification{
        resource: Page,
        action: %{name: :create},
        data: %{id: page_id, title: "Summer Activities"}
      }

      assert page_id == page.id
    end

    test "returns the existing page for the same normalized title" do
      assert {:ok, first_page} = Page.ensure("Summer   Activities")
      assert {:ok, second_page} = Page.ensure("  Summer Activities ")

      assert second_page.id == first_page.id
      assert length(Ash.read!(Page)) == 1
    end

    test "preserves unicode letters in slugs" do
      assert {:ok, page} = Page.ensure("Café Ideas")

      assert page.slug == "café-ideas"
    end

    test "creates different pages for different titles" do
      assert {:ok, home} = Page.ensure("Home")
      assert {:ok, summer_activities} = Page.ensure("Summer Activities")

      refute summer_activities.id == home.id
    end

    test "rejects blank titles" do
      assert {:error, _error} = Page.ensure("   ")

      assert Ash.read!(Page) == []
    end

    test "rejects a different title that produces an existing slug" do
      Page.ensure!("Summer Activities")

      assert {:error, _error} = Page.ensure("Summer—Activities")
      assert length(Ash.read!(Page)) == 1
    end

    test "concurrent calls converge on one page" do
      pages =
        1..10
        |> Task.async_stream(
          fn _ -> Page.ensure!("Shared Page") end,
          max_concurrency: 10,
          ordered: false,
          timeout: 10_000
        )
        |> Enum.map(fn {:ok, page} -> page end)

      assert pages |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 1
      assert length(Ash.read!(Page)) == 1
    end
  end

  describe "fetch_by_slug/1" do
    test "returns nil for a valid slug that does not exist" do
      assert {:ok, nil} = Page.fetch_by_slug("summer-activities")
      assert Ash.read!(Page) == []
    end

    test "returns an existing page" do
      page = Page.ensure!("Summer Activities")

      assert {:ok, fetched_page} = Page.fetch_by_slug("summer-activities")
      assert fetched_page.id == page.id
    end

    test "rejects invalid route slugs" do
      assert {:error, _error} = Page.fetch_by_slug("Summer Activities")
    end
  end

  describe "rename/2" do
    test "changes the title and slug without changing the page id" do
      page = Page.ensure!("Summer Activities")

      renamed_page = Page.rename!(page, "  Winter   Activities ")

      assert renamed_page.id == page.id
      assert renamed_page.title == "Winter Activities"
      assert renamed_page.slug == "winter-activities"
    end

    test "rejects a slug collision" do
      Page.ensure!("Winter Activities")
      summer = Page.ensure!("Summer Activities")

      assert {:error, _error} = Page.rename(summer, "Winter Activities")
      assert Page.get!(summer.id).slug == "summer-activities"
    end

    test "publishes a notification after a successful rename" do
      page = Page.ensure!("Summer Activities")
      Page.subscribe()

      renamed_page = Page.rename!(page, "Winter Activities")

      assert_receive %Ash.Notifier.Notification{
        resource: Page,
        action: %{name: :rename},
        data: %{id: page_id, title: "Winter Activities"}
      }

      assert page_id == renamed_page.id
    end
  end

  describe "list/0" do
    test "returns all pages sorted by title" do
      Page.ensure!("Summer Activities")
      Page.ensure!("Home")
      Page.ensure!("About")

      assert Page.list!() |> Enum.map(& &1.title) == [
               "About",
               "Home",
               "Summer Activities"
             ]
    end
  end
end
