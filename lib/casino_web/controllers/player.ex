defmodule CasinoWeb.Controllers.Player do
  use CasinoWeb, :controller

  def init(opts), do: opts

  def get(conn = %{params: %{"id" => id}}, _) do
    id
    |> Casino.get_player()
    |> case do
      nil ->
        json(conn, %{error: "User with id #{id} does not exist."})

      player = %BlackJack.Player{} ->
        json(conn, Map.from_struct(player))

      other ->
        json(conn, %{"wtf" => inspect(other)})
    end
  end

  def post(conn = %{body_params: player_params}, _opts) do
    player_params
    |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)
    |> Casino.upsert_player()
    |> Map.from_struct()
    |> Map.drop([:hands, :insurance, :ready, :valid_wager])
    |> (respond(conn)).()
  end

  def post(conn, _info) do
    conn
    |> resp(400, "missing information")
  end

  defp respond(conn) do
    fn response ->
      json(conn, response)
    end
  end
end
