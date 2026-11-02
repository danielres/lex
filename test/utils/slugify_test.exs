defmodule Utils.SlugifyTest do
  use ExUnit.Case, async: true

  alias Utils.Slugify

  test "generates an ASCII slug" do
    assert Slugify.generate("  Déjà Vu!  ") == "deja-vu"
  end
end
