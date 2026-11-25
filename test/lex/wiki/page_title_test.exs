defmodule Lex.Wiki.PageTitleTest do
  use ExUnit.Case, async: true

  alias Lex.Wiki.PageTitle

  test "normalizes whitespace and capitalizes only the first grapheme" do
    assert PageTitle.normalize("  été   à l'Assemblée  ") == {:ok, "Été à l'Assemblée"}
  end

  test "derives a suggested title from a slug" do
    assert PageTitle.from_slug("été-à-l-assemblée") == "Été à l assemblée"
  end
end
