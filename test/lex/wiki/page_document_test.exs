defmodule Lex.Wiki.PageDocumentTest do
  use Lex.DataCase

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument

  setup do
    {:ok, scope: create_scope()}
  end

  test "persists and restores a document", %{scope: scope} do
    page = scope |> Page.ensure!("home")

    assert :ok = scope |> Page.persist_document(page, "main", document("first version"))
    assert scope |> restored_text(page, "main") == "first version"
    [first_document] = Ash.read!(PageDocument)

    assert :ok = scope |> Page.persist_document(page, "main", document("second version"))
    assert scope |> restored_text(page, "main") == "second version"
    [second_document] = Ash.read!(PageDocument)

    assert DateTime.after?(second_document.updated_at, first_document.updated_at)
  end

  test "saves page content with its searchable text and content hash", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("First version", format: 0)

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               page,
               "main",
               document("first version"),
               %{lexical_state: lexical_state, search_text: "First version"}
             )

    [page_document] = Ash.read!(PageDocument)

    assert page_document.lexical_state == lexical_state
    assert page_document.search_text == "First version"
    assert String.length(page_document.content_hash) == 64

    assert {:ok, content} = scope |> Page.get_document_content(page, "main")
    assert content.lexical_state == lexical_state
    assert content.content_hash == page_document.content_hash
  end

  test "persists empty nested document content", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("", format: 0)

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               page,
               "caption-1",
               document(""),
               %{lexical_state: lexical_state, search_text: ""}
             )

    [page_document] = Ash.read!(PageDocument, scope: scope)

    assert page_document.lexical_state == lexical_state
    assert page_document.search_text == ""
  end

  test "persists a non-text document with empty searchable text", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    lexical_state = %{
      "root" => %{
        "children" => [%{"type" => "horizontalrule", "version" => 1}],
        "type" => "root",
        "version" => 1
      }
    }

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               page,
               "main",
               document(""),
               %{lexical_state: lexical_state, search_text: ""}
             )

    [page_document] = Ash.read!(PageDocument, scope: scope)
    assert page_document.search_text == ""
  end

  test "rejects page content without searchable text", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    result =
      PageDocument
      |> Ash.Changeset.for_create(:save, %{
        content_hash: String.duplicate("0", 64),
        document_key: "main",
        lexical_state: lexical_state("Text", format: 0),
        page_id: page.id,
        yjs_state: <<0>>
      })
      |> Ash.create(scope: scope)

    assert {:error, %Ash.Error.Invalid{errors: errors}} = result

    assert Enum.any?(
             errors,
             &match?(%Ash.Error.Changes.Required{field: :search_text}, &1)
           )
  end

  test "returns no page content before a document is saved", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert {:ok, nil} = scope |> Page.get_document_content(page, "main")
  end

  test "does not update unchanged page content", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("Same content", format: 0)
    content = %{lexical_state: lexical_state, search_text: "Same content"}

    assert {:ok, :saved} =
             scope |> Page.save_document(page, "main", document("first state"), content)

    [first_document] = Ash.read!(PageDocument)

    assert {:ok, :unchanged} =
             scope
             |> Page.save_document(page, "main", document("different yjs state"), content)

    [second_document] = Ash.read!(PageDocument)

    assert second_document.updated_at == first_document.updated_at
    assert second_document.yjs_state == first_document.yjs_state
  end

  test "persists formatting changes when searchable text is unchanged", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               page,
               "main",
               document("text"),
               %{lexical_state: lexical_state("Text", format: 0), search_text: "Text"}
             )

    [first_document] = Ash.read!(PageDocument)

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               page,
               "main",
               document("text"),
               %{lexical_state: lexical_state("Text", format: 1), search_text: "Text"}
             )

    [second_document] = Ash.read!(PageDocument)

    refute second_document.content_hash == first_document.content_hash
  end

  test "persisting only Yjs state preserves existing page content", %{scope: scope} do
    page = scope |> Page.ensure!("Home")
    lexical_state = lexical_state("Searchable", format: 0)

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               page,
               "main",
               document("first"),
               %{lexical_state: lexical_state, search_text: "Searchable"}
             )

    assert :ok = scope |> Page.persist_document(page, "main", document("second"))

    [page_document] = Ash.read!(PageDocument)

    assert page_document.lexical_state == lexical_state
    assert page_document.search_text == "Searchable"
  end

  test "advances the page's last update when a document is persisted", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert [page_before_persist] = Page.list!(scope: scope)
    assert page_before_persist.last_updated_at == page.updated_at

    assert :ok = scope |> Page.persist_document(page, "main", document("first version"))

    assert [page_after_persist] = Page.list!(scope: scope)
    assert DateTime.after?(page_after_persist.last_updated_at, page.updated_at)
  end

  test "uses the newest persisted nested document", %{scope: scope} do
    page = scope |> Page.ensure!("Home")

    assert :ok = scope |> Page.persist_document(page, "main", document("main"))
    [main_document] = Ash.read!(PageDocument)

    assert :ok = scope |> Page.persist_document(page, "caption-1", document("caption"))

    page = Page.list!(scope: scope) |> List.first()
    latest_document = PageDocument |> Ash.Query.sort(updated_at: :desc) |> Ash.read_first!()

    assert DateTime.after?(latest_document.updated_at, main_document.updated_at)
    assert page.last_updated_at == latest_document.updated_at
  end

  test "keeps pages and nested document keys isolated", %{scope: scope} do
    first_page = scope |> Page.ensure!("first-page")
    second_page = scope |> Page.ensure!("second-page")

    assert :ok = scope |> Page.persist_document(first_page, "main", document("first main"))

    assert :ok =
             scope
             |> Page.persist_document(first_page, "caption-1", document("first caption"))

    assert :ok = scope |> Page.persist_document(second_page, "main", document("second main"))

    assert scope |> restored_text(first_page, "main") == "first main"
    assert scope |> restored_text(first_page, "caption-1") == "first caption"
    assert scope |> restored_text(second_page, "main") == "second main"
  end

  test "restoring a document without persisted state leaves it empty", %{scope: scope} do
    page = scope |> Page.ensure!("home")

    assert scope |> restored_text(page, "main") == ""
  end

  test "rejects invalid document keys", %{scope: scope} do
    page = scope |> Page.ensure!("home")

    assert {:error, _error} = scope |> Page.persist_document(page, "", document("text"))

    assert {:error, _error} =
             scope
             |> Page.persist_document(page, String.duplicate("x", 256), document("text"))
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
