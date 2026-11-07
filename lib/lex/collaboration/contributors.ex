defmodule Lex.Collaboration.Contributors do
  @moduledoc false

  use GenServer

  def start_link(options) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(options, :name, __MODULE__))
  end

  def record(room, user_id) do
    GenServer.call(__MODULE__, {:record, room, user_id})
  end

  def capture(rooms) do
    GenServer.call(__MODULE__, {:capture, Enum.uniq(rooms)})
  end

  def acknowledge(%{rooms: rooms, sequence: sequence}) do
    GenServer.call(__MODULE__, {:acknowledge, rooms, sequence})
  end

  @impl true
  def init(_state) do
    {:ok, %{rooms: %{}, sequence: 0}}
  end

  @impl true
  def handle_call({:record, room, user_id}, _from, state) do
    sequence = state.sequence + 1

    rooms =
      Map.update(state.rooms, room, %{user_id => sequence}, fn contributors ->
        Map.put(contributors, user_id, sequence)
      end)

    {:reply, :ok, %{state | rooms: rooms, sequence: sequence}}
  end

  def handle_call({:capture, rooms}, _from, state) do
    contributor_ids =
      rooms
      |> Enum.flat_map(fn room -> state.rooms |> Map.get(room, %{}) |> Map.keys() end)
      |> Enum.uniq()

    capture = %{
      contributor_ids: contributor_ids,
      rooms: rooms,
      sequence: state.sequence
    }

    {:reply, capture, state}
  end

  def handle_call({:acknowledge, rooms, sequence}, _from, state) do
    tracked_rooms =
      Enum.reduce(rooms, state.rooms, fn room, tracked_rooms ->
        contributors =
          tracked_rooms
          |> Map.get(room, %{})
          |> Map.reject(fn {_user_id, contribution_sequence} ->
            contribution_sequence <= sequence
          end)

        if contributors == %{} do
          Map.delete(tracked_rooms, room)
        else
          Map.put(tracked_rooms, room, contributors)
        end
      end)

    {:reply, :ok, %{state | rooms: tracked_rooms}}
  end
end
