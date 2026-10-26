defmodule Lex.Wiki.PageRevisionTest do
  use Lex.DataCase

  alias Lex.Wiki.Page

  test "stores immutable semantic revisions and skips consecutive duplicates" do
    page = Page.ensure!("Home")
    first_state = lexical_state("First version")
    second_state = lexical_state("Second version")

    assert {:ok, :saved} =
             Page.set_checkpoint(
               page,
               %{lexical_state: first_state, search_text: "First version"},
               nil
             )

    assert {:ok, :unchanged} =
             Page.set_checkpoint(
               page,
               %{lexical_state: first_state, search_text: "First version"},
               nil
             )

    assert {:ok, :saved} =
             Page.set_checkpoint(
               page,
               %{lexical_state: second_state, search_text: "Second version"},
               nil
             )

    [second_revision, first_revision] = Page.list_revisions!(page)

    assert second_revision.lexical_state == second_state
    assert second_revision.search_text == "Second version"
    assert first_revision.lexical_state == first_state
    assert first_revision.search_text == "First version"
  end

  test "records restore provenance and requires the source revision to belong to the page" do
    page = Page.ensure!("Home")
    other_page = Page.ensure!("Other Page")
    first_state = lexical_state("First version")

    assert {:ok, :saved} =
             Page.set_checkpoint(
               page,
               %{lexical_state: first_state, search_text: "First version"},
               nil
             )

    [source_revision] = Page.list_revisions!(page)

    assert {:ok, :saved} =
             Page.set_checkpoint(
               page,
               %{
                 lexical_state: lexical_state("Restored version"),
                 search_text: "Restored version"
               },
               source_revision.id
             )

    [restored_revision, ^source_revision] = Page.list_revisions!(page)
    assert restored_revision.restored_from_revision_id == source_revision.id

    assert {:error, _error} =
             Page.set_checkpoint(
               other_page,
               %{lexical_state: lexical_state("Invalid"), search_text: "Invalid"},
               source_revision.id
             )

    assert Page.list_revisions!(other_page) == []
  end

  defp lexical_state(text) do
    %{
      "root" => %{
        "children" => [
          %{
            "children" => [
              %{
                "detail" => 0,
                "format" => 0,
                "mode" => "normal",
                "style" => "",
                "text" => text,
                "type" => "text",
                "version" => 1
              }
            ],
            "type" => "paragraph",
            "version" => 1
          }
        ],
        "type" => "root",
        "version" => 1
      }
    }
  end
end
