defmodule Lex.Wiki.PageNameTest do
  use ExUnit.Case, async: true

  alias Lex.Wiki.PageName

  test "normalizes whitespace and capitalizes only the first grapheme" do
    assert PageName.normalize("  été   à l'Assemblée  ") == {:ok, "Été à l'Assemblée"}
  end

  test "does not capitalize when that would change the slug" do
    assert PageName.normalize("ßeta") == {:ok, "ßeta"}
    assert PageName.slug("ßeta") == {:ok, "ßeta"}
    assert PageName.from_slug("ßeta") == "ßeta"
  end

  test "derives a suggested title from a slug" do
    assert PageName.from_slug("été-à-l-assemblée") == "Été à l assemblée"
  end
end
