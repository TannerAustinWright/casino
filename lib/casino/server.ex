defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.
  """
  use Casino.GenServer

  alias BlackJack.{
    Game,
    Player
  }

  def start_link(options \\ []),
    do: GenServer.start_link(__MODULE__, %{}, options)

  def init(_state), do: {:ok, Game.new!()}

  def handle_call({:get_player, player_id}, _from, state) do
    state
    |> Game.get_player(player_id)
    |> reply(state)
  end

  def handle_call({:create_player, name}, _from, state) do
    player = Player.new!(name: name)

    reply(player, Game.create_player(state, player))
  end

  def handle_cast({:join, player_id}, state) do
  end

  def handle_cast({:place_bet, player_id, wager, ready}, state) do
  end

  def handle_cast({:buy_insurance, player_id, wager, ready}, state) do
  end

  def handle_cast({:split, player_id, split}, state) do
  end

  def handle_cast({:hit, player_id}, state) do
  end

  def handle_cast({:stand, player_id}, state) do
  end

  def handle_cast({:double_down, player_id}, state) do
  end

  def handle_cast({:surrender, player_id}, state) do
  end

  defp broadcast(state), do: MyAppWeb.Endpoint.broadcast("game:lobby", "state_update", state)
end
