defmodule Lex.Accounts.Privilege do
  use Ash.Type.Enum,
    values: [
      edit_pages: "Create and edit wiki pages",
      manage_members: "Invite, reinvite, and deactivate members",
      manage_privileges: "Change other members' privileges",
      manage_space: "Change space settings"
    ]
end
