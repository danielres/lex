defmodule Lex.Wiki.PageDocumentTest do
  use Lex.DataCase

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument

  test "sets and restores a checkpoint" do
    page = Page.ensure!("home")

    assert :ok = Page.set_checkpoint(page, "main", document("first version"))
    assert restored_text(page, "main") == "first version"
    [first_checkpoint] = Ash.read!(PageDocument)

    assert :ok = Page.set_checkpoint(page, "main", document("second version"))
    assert restored_text(page, "main") == "second version"
    [second_checkpoint] = Ash.read!(PageDocument)

    assert DateTime.after?(second_checkpoint.updated_at, first_checkpoint.updated_at)
  end

  test "advances the page's last update when a document is checkpointed" do
    page = Page.ensure!("Home")

    assert [page_before_checkpoint] = Page.list!()
    assert page_before_checkpoint.last_updated_at == page.updated_at

    assert :ok = Page.set_checkpoint(page, "main", document("first version"))

    assert [page_after_checkpoint] = Page.list!()
    assert DateTime.after?(page_after_checkpoint.last_updated_at, page.updated_at)
  end

  test "uses the newest checkpoint across nested documents" do
    page = Page.ensure!("Home")

    assert :ok = Page.set_checkpoint(page, "main", document("main"))
    [main_document] = Ash.read!(PageDocument)

    assert :ok = Page.set_checkpoint(page, "caption-1", document("caption"))

    page = Page.list!() |> List.first()
    latest_document = PageDocument |> Ash.Query.sort(updated_at: :desc) |> Ash.read_first!()

    assert DateTime.after?(latest_document.updated_at, main_document.updated_at)
    assert page.last_updated_at == latest_document.updated_at
  end

  test "keeps pages and nested document keys isolated" do
    first_page = Page.ensure!("first-page")
    second_page = Page.ensure!("second-page")

    assert :ok = Page.set_checkpoint(first_page, "main", document("first main"))
    assert :ok = Page.set_checkpoint(first_page, "caption-1", document("first caption"))
    assert :ok = Page.set_checkpoint(second_page, "main", document("second main"))

    assert restored_text(first_page, "main") == "first main"
    assert restored_text(first_page, "caption-1") == "first caption"
    assert restored_text(second_page, "main") == "second main"
  end

  test "restoring a document without a checkpoint leaves it empty" do
    page = Page.ensure!("home")

    assert restored_text(page, "main") == ""
  end

  test "rejects invalid document keys" do
    page = Page.ensure!("home")

    assert {:error, _error} = Page.set_checkpoint(page, "", document("text"))

    assert {:error, _error} =
             Page.set_checkpoint(page, String.duplicate("x", 256), document("text"))
  end

  defp document(text) do
    doc = Yex.Doc.new()
    doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, text)
    doc
  end

  defp restored_text(page, document_key) do
    doc = Yex.Doc.new()
    assert :ok = Page.restore(page, document_key, doc)
    doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string()
  end
end
