defmodule Lex.Collaboration.ContributorsTest do
  use ExUnit.Case

  alias Lex.Collaboration.Contributors

  test "captures distinct contributors across documents" do
    prefix = System.unique_integer([:positive])
    main_room = "#{prefix}/main"
    caption_room = "#{prefix}/caption"
    first_user_id = Ash.UUID.generate()
    second_user_id = Ash.UUID.generate()

    :ok = Contributors.record(main_room, first_user_id)
    :ok = Contributors.record(main_room, first_user_id)
    :ok = Contributors.record(caption_room, first_user_id)
    :ok = Contributors.record(caption_room, second_user_id)

    capture = Contributors.capture([main_room, caption_room])

    assert Enum.sort(capture.contributor_ids) == Enum.sort([first_user_id, second_user_id])
  end

  test "acknowledges captured contributions without clearing newer updates" do
    room = "#{System.unique_integer([:positive])}/main"
    first_user_id = Ash.UUID.generate()
    second_user_id = Ash.UUID.generate()

    :ok = Contributors.record(room, first_user_id)
    first_capture = Contributors.capture([room])

    :ok = Contributors.record(room, first_user_id)
    :ok = Contributors.record(room, second_user_id)
    :ok = Contributors.acknowledge(first_capture)

    second_capture = Contributors.capture([room])

    assert Enum.sort(second_capture.contributor_ids) ==
             Enum.sort([first_user_id, second_user_id])

    :ok = Contributors.acknowledge(second_capture)
    assert Contributors.capture([room]).contributor_ids == []
  end
end
