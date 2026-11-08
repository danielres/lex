defmodule Lex.Accounts.Privilege do
  use Ash.Type.Enum,
    values: [
      edit_pages: "Create and edit wiki pages",
      manage_members: "Invite, reinvite, and disable members",
      manage_privileges: "Change other members' privileges",
      manage_space: "Change space settings",
      view_disabled_memberships: "View disabled memberships",
      view_pending_memberships: "View pending memberships"
    ]
end
