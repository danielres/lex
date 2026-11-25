defmodule Lex.Changes.GenerateSlug do
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    source = Keyword.fetch!(opts, :from)
    target = Keyword.get(opts, :to, :slug)

    case Ash.Changeset.fetch_change(changeset, source) do
      {:ok, value} when is_binary(value) ->
        slug = Utils.Slugify.generate(value)

        if slug == "" do
          Ash.Changeset.add_error(changeset,
            field: source,
            message: "must contain at least one letter or number"
          )
        else
          Ash.Changeset.force_change_attribute(changeset, target, slug)
        end

      _other ->
        changeset
    end
  end

  @impl true
  def temporal_safe?(_opts), do: true
end
