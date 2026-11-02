defmodule Utils.Slugify do
  @marks ~r/\p{M}/u
  @separator ~r/[^a-z0-9]+/u

  @spec generate(String.t()) :: String.t()
  def generate(value) when is_binary(value) do
    value
    |> String.normalize(:nfd)
    |> String.replace(@marks, "")
    |> String.downcase()
    |> String.replace(@separator, "-")
    |> String.trim("-")
  end
end
