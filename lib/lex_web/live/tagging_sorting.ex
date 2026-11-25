defmodule LexWeb.Live.TaggingSorting do
  import Phoenix.LiveView, only: [get_connect_params: 1, push_event: 3]

  @default %{by: :interest, direction: :desc}
  @fields %{"alpha" => :alpha, "experience" => :experience, "interest" => :interest}
  @directions %{"asc" => :asc, "desc" => :desc}

  def load(socket, preference) do
    user_id = socket.assigns.scope.user.id
    params = get_connect_params(socket) || %{}

    with %{"by" => by, "direction" => direction} <-
           get_in(params, ["local_settings", "users", user_id, Atom.to_string(preference), "sorting"]),
         {:ok, by} <- Map.fetch(@fields, by),
         {:ok, direction} <- Map.fetch(@directions, direction) do
      %{by: by, direction: direction}
    else
      _other -> @default
    end
  end

  def change(current, value) do
    with {:ok, by} <- Map.fetch(@fields, value) do
      direction =
        case current do
          %{by: ^by, direction: :asc} -> :desc
          %{by: ^by, direction: :desc} -> :asc
          _other -> if by == :alpha, do: :asc, else: :desc
        end

      {:ok, %{by: by, direction: direction}}
    end
  end

  def persist(socket, preference, sorting) do
    user_id = socket.assigns.scope.user.id
    values = %{by: Atom.to_string(sorting.by), direction: Atom.to_string(sorting.direction)}
    push_event(socket, "local-settings-changed", %{users: %{user_id => %{preference => %{sorting: values}}}})
  end
end
