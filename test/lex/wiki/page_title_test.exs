defmodule Lex.Wiki.PageTitleTest do
  use ExUnit.Case, async: true

  alias Lex.Wiki.PageTitle

  test "normalizes whitespace and capitalizes only the first grapheme" do
    assert PageTitle.normalize("  été   à l'Assemblée  ") == {:ok, "Été à l'Assemblée"}
  end

  test "does not capitalize when that would change the slug" do
    assert PageTitle.normalize("ßeta") == {:ok, "ßeta"}
    assert PageTitle.slug("ßeta") == {:ok, "ßeta"}
    assert PageTitle.from_slug("ßeta") == "ßeta"
  end

  test "derives a suggested title from a slug" do
    assert PageTitle.from_slug("été-à-l-assemblée") == "Été à l assemblée"
  end
end
