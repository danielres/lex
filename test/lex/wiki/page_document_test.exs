defmodule Lex.Wiki.PageDocumentTest do
  use Lex.DataCase

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument

  setup do
    {:ok, scope: create_scope()}
  end

  test "sets and restores a checkpoint", %{scope: scope} do
    page = scope |> Page.ensure!("home")

    assert :ok = scope |> Page.set_checkpoint(page, "main", document("first version"))
    assert scope |> restored_text(page, "main") == "first version"
    [first_checkpoint] = Ash.read!(PageDocument)

    assert :ok = scope |> Page.set_checkpoint(page, "main", document("second version"))
    assert scope |> restored_text(page, "main") == "second version"
    [second_checkpoint] = Ash.read!(PageDocument)

    assert DateTime.after?(second_checkpoint.updated_at, first_checkpoint.updated_at)
  end

  test "persists a semantic snapshot with its searchable text and content hash", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("First version", format: 0)

    assert {:ok, :saved} =
             scope
             |> Page.set_checkpoint(
               page,
               "main",
               document("first version"),
               %{lexical_state: lexical_state, search_text: "First version"}
             )

    [page_document] = Ash.read!(PageDocument)

    assert page_document.lexical_state == lexical_state
    assert page_document.search_text == "First version"
    assert String.length(page_document.content_hash) == 64
  end

  test "does not update an unchanged semantic snapshot", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("Same content", format: 0)
    snapshot = %{lexical_state: lexical_state, search_text: "Same content"}

    assert {:ok, :saved} =
             scope |> Page.set_checkpoint(page, "main", document("first state"), snapshot)

    [first_checkpoint] = Ash.read!(PageDocument)

    assert {:ok, :unchanged} =
             scope
             |> Page.set_checkpoint(page, "main", document("different yjs state"), snapshot)

    [second_checkpoint] = Ash.read!(PageDocument)

    assert second_checkpoint.updated_at == first_checkpoint.updated_at
    assert second_checkpoint.yjs_state == first_checkpoint.yjs_state
  end

  test "persists formatting changes when searchable text is unchanged", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert {:ok, :saved} =
             scope
             |> Page.set_checkpoint(
               page,
               "main",
               document("text"),
               %{lexical_state: lexical_state("Text", format: 0), search_text: "Text"}
             )

    [first_checkpoint] = Ash.read!(PageDocument)

    assert {:ok, :saved} =
             scope
             |> Page.set_checkpoint(
               page,
               "main",
               document("text"),
               %{lexical_state: lexical_state("Text", format: 1), search_text: "Text"}
             )

    [second_checkpoint] = Ash.read!(PageDocument)

    refute second_checkpoint.content_hash == first_checkpoint.content_hash
  end

  test "a Yjs-only checkpoint preserves an existing semantic snapshot", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("Searchable", format: 0)

    assert {:ok, :saved} =
             scope
             |> Page.set_checkpoint(
               page,
               "main",
               document("first"),
               %{lexical_state: lexical_state, search_text: "Searchable"}
             )

    assert :ok = scope |> Page.set_checkpoint(page, "main", document("second"))

    [page_document] = Ash.read!(PageDocument)

    assert page_document.lexical_state == lexical_state
    assert page_document.search_text == "Searchable"
  end

  test "advances the page's last update when a document is checkpointed", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert [page_before_checkpoint] = Page.list!(scope: scope)
    assert page_before_checkpoint.last_updated_at == page.updated_at

    assert :ok = scope |> Page.set_checkpoint(page, "main", document("first version"))

    assert [page_after_checkpoint] = Page.list!(scope: scope)
    assert DateTime.after?(page_after_checkpoint.last_updated_at, page.updated_at)
  end

  test "uses the newest checkpoint across nested documents", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert :ok = scope |> Page.set_checkpoint(page, "main", document("main"))
    [main_document] = Ash.read!(PageDocument)

    assert :ok = scope |> Page.set_checkpoint(page, "caption-1", document("caption"))

    page = Page.list!(scope: scope) |> List.first()
    latest_document = PageDocument |> Ash.Query.sort(updated_at: :desc) |> Ash.read_first!()

    assert DateTime.after?(latest_document.updated_at, main_document.updated_at)
    assert page.last_updated_at == latest_document.updated_at
  end

  test "keeps pages and nested document keys isolated", %{scope: scope} do
    first_page = scope |> Page.ensure!("first-page")
    second_page = scope |> Page.ensure!("second-page")

    assert :ok = scope |> Page.set_checkpoint(first_page, "main", document("first main"))

    assert :ok =
             scope
             |> Page.set_checkpoint(first_page, "caption-1", document("first caption"))

    assert :ok = scope |> Page.set_checkpoint(second_page, "main", document("second main"))

    assert scope |> restored_text(first_page, "main") == "first main"
    assert scope |> restored_text(first_page, "caption-1") == "first caption"
    assert scope |> restored_text(second_page, "main") == "second main"
  end

  test "restoring a document without a checkpoint leaves it empty", %{scope: scope} do
    page = scope |> Page.ensure!("home")

    assert scope |> restored_text(page, "main") == ""
  end

  test "rejects invalid document keys", %{scope: scope} do
    page = scope |> Page.ensure!("home")

    assert {:error, _error} = scope |> Page.set_checkpoint(page, "", document("text"))

    assert {:error, _error} =
             scope
             |> Page.set_checkpoint(page, String.duplicate("x", 256), document("text"))
  end

  defp document(text) do
    doc = Yex.Doc.new()
    doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, text)
    doc
  end

  defp lexical_state(text, options) do
    %{
      "root" => %{
        "children" => [
          %{
            "children" => [
              %{
                "detail" => 0,
                "format" => Keyword.fetch!(options, :format),
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

  defp restored_text(scope, page, document_key) do
    doc = Yex.Doc.new()
    assert :ok = scope |> Page.restore(page, document_key, doc)
    doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string()
  end
end
