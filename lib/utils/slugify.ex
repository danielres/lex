defmodule Utils.Slugify do
  @separator ~r/[^\p{L}\p{N}]+/u

  @spec generate(String.t()) :: String.t()
  def generate(value) when is_binary(value) do
    value
    |> String.normalize(:nfc)
    |> String.downcase()
    |> String.replace(@separator, "-")
    |> String.trim("-")
  end
end
