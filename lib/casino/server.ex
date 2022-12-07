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

  def handle_cast({:join, _player_id}, state) do
    broadcast(state)
    state
  end

  def handle_cast({:place_bet, _player_id, _wager, _ready}, state) do
    state
  end

  def handle_cast({:buy_insurance, _player_id, _wager, _ready}, state) do
    state
  end

  def handle_cast({:split, _player_id, _split}, state) do
    state
  end

  def handle_cast({:hit, _player_id}, state) do
    state
  end

  def handle_cast({:stand, _player_id}, state) do
    state
  end

  def handle_cast({:double_down, _player_id}, state) do
    state
  end

  def handle_cast({:surrender, _player_id}, state) do
    state
  end

  defp broadcast(state), do: CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", state)
end
