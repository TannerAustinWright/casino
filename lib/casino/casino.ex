defmodule Casino do
  @moduledoc """
  The api layer for the casino module.
  """
  alias Casino.Server

  def get_player(player_id),
    do: GenServer.call(Server, {:get_player, player_id})

  def upsert_player(player_params),
    do: GenServer.call(Server, {:upsert_player, player_params})

  def get_state(),
    do: GenServer.call(Server, :get_state)

  def clear_state(),
    do: GenServer.cast(Server, :clear_state)

  def join(player_id),
    do: GenServer.cast(Server, {:join, player_id})

  def bet(player_id, wager),
    do: GenServer.cast(Server, {:bet, player_id, wager})

  def buy_insurance(player_id, wants_insurance),
    do: GenServer.cast(Server, {:buy_insurance, player_id, wants_insurance})

  def split(player_id),
    do: GenServer.cast(Server, {:split, player_id})

  def hit(player_id),
    do: GenServer.cast(Server, {:hit, player_id})

  def stand(player_id),
    do: GenServer.cast(Server, {:stand, player_id})

  def double_down(player_id),
    do: GenServer.cast(Server, {:double_down, player_id})

  def surrender(player_id),
    do: GenServer.cast(Server, {:surrender, player_id})
end
