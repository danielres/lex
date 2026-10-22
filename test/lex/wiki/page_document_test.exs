defmodule Lex.Wiki.PageDocumentTest do
  use Lex.DataCase

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument

  test "sets and restores a checkpoint" do
    page = Page.ensure!("home")

    assert :ok = Page.set_checkpoint(page, "main", document("first version"))
    assert restored_text(page, "main") == "first version"

    assert :ok = Page.set_checkpoint(page, "main", document("second version"))
    assert restored_text(page, "main") == "second version"
    assert length(Ash.read!(PageDocument)) == 1
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
