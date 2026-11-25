defmodule Utils.SlugifyTest do
  use ExUnit.Case, async: true

  alias Utils.Slugify

  test "generates a Unicode slug" do
    assert Slugify.generate("  Déjà Vu!  ") == "déjà-vu"
    assert Slugify.generate("東京 Guide") == "東京-guide"
  end
end
