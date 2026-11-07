defmodule Lex.Accounts.Membership.Changes.SetIdentity do
  use Ash.Resource.Change

  alias Utils.Slugify

  @impl true
  def change(changeset, _options, _context) do
    membership = changeset.data
    display_name = Ash.Changeset.get_argument(changeset, :display_name)

    cond do
      membership.display_name != nil ->
        changeset

      is_binary(display_name) ->
        changeset |> set_identity(display_name)

      true ->
        Ash.Changeset.add_error(changeset,
          field: :display_name,
          message: "is required"
        )
    end
  end

  defp set_identity(changeset, display_name) do
    display_name = display_name |> String.split() |> Enum.join(" ")
    slug = Slugify.generate(display_name)

    if slug == "" do
      Ash.Changeset.add_error(changeset,
        field: :display_name,
        message: "Must contain at least one letter or number"
      )
    else
      changeset
      |> Ash.Changeset.force_change_attribute(:display_name, display_name)
      |> Ash.Changeset.force_change_attribute(:slug, slug)
    end
  end
end
