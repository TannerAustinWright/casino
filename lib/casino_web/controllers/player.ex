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

  def post(conn = %{body_params: %{"name" => name}}, _opts) do
    json(conn, Map.from_struct(Casino.create_player(name)))
  end
end
