defmodule Casino do
  @moduledoc """
  The api layer for the casino module.
  """
  alias Casino.Server

  def get_player(player_id),
    do: GenServer.call(Server, {:get_player, player_id})

  def create_player(name),
    do: GenServer.call(Server, {:create_player, name})

  def get_state(),
    do: GenServer.call(Server, :get_state)

  def clear_state(),
    do: GenServer.cast(Server, :clear_state)

  def join(player_id),
    do: GenServer.cast(Server, {:join, player_id})

  def place_bet(player_id, wager, ready),
    do: GenServer.cast(Server, {:place_bet, player_id, wager, ready})

  def buy_insurance(player_id, wager, ready),
    do: GenServer.cast(Server, {:buy_insurance, player_id, wager, ready})

  def split(player_id, split),
    do: GenServer.cast(Server, {:split, player_id, split})

  def hit(player_id),
    do: GenServer.cast(Server, {:hit, player_id})

  def stand(player_id),
    do: GenServer.cast(Server, {:stand, player_id})

  def double_down(player_id),
    do: GenServer.cast(Server, {:double_down, player_id})

  def surrender(player_id),
    do: GenServer.cast(Server, {:surrender, player_id})
end
