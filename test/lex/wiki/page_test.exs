defmodule Lex.Wiki.PageTest do
  use Lex.DataCase

  alias Lex.Wiki
  alias Lex.Wiki.Page

  describe "ensure_page/1" do
    test "creates a page for a valid slug" do
      assert {:ok, page} = Wiki.ensure_page("home")

      assert page.slug == "home"
      assert {:ok, page.id} == Ecto.UUID.cast(page.id)
    end

    test "returns the existing page for the same slug" do
      assert {:ok, first_page} = Wiki.ensure_page("summer-activities")
      assert {:ok, second_page} = Wiki.ensure_page("summer-activities")

      assert second_page.id == first_page.id
      assert length(Ash.read!(Page)) == 1
    end

    test "creates different pages for different slugs" do
      assert {:ok, home} = Wiki.ensure_page("home")
      assert {:ok, summer_activities} = Wiki.ensure_page("summer-activities")

      refute summer_activities.id == home.id
    end

    test "rejects invalid slugs" do
      for slug <- ["Summer-Activities", "summer activities", "summer_activities", "-summer"] do
        assert {:error, _error} = Wiki.ensure_page(slug)
      end

      assert Ash.read!(Page) == []
    end

    test "concurrent calls converge on one page" do
      pages =
        1..10
        |> Task.async_stream(
          fn _ -> Wiki.ensure_page!("shared-page") end,
          max_concurrency: 10,
          ordered: false,
          timeout: 10_000
        )
        |> Enum.map(fn {:ok, page} -> page end)

      assert pages |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 1
      assert length(Ash.read!(Page)) == 1
    end
  end
end
