defmodule LexWeb.Components.ResourceInfo do
  use LexWeb, :html

  alias LexWeb.Components.Avatar

  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :author, :map, required: true
  attr :inserted_at, :any, required: true
  attr :rest, :global

  def created_by(assigns) do
    ~H"""
    <div class="space-y-1" {@rest}>
      <h2 class="small-caps text-lg">Created by</h2>
      <div class="flex items-baseline gap-2 ml-4">
        <Avatar.render user={@author} />
        <span class="opacity-100">{@author.display_name}</span>
        <span class="text-sm">{Utils.Time.relative(@inserted_at)}</span>
      </div>
    </div>
    """
  end

  attr :path, :string, required: true, doc: "The space-scoped URL path."

  def path_preview(assigns) do
    ~H"""
    <div class="opacity-80 font-mono">{decode_path(@path)}</div>
    """
  end

  defp decode_path(path) do
    path = path |> String.split("/") |> Enum.drop(2) |> Enum.join("/")
    "/" <> URI.decode(path)
  end
end
