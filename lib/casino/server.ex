defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.
  """
  use Casino.GenServer
  require Logger

  alias BlackJack.{
    Game,
    Player,
    Hand
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

  def handle_call(:get_state, _from, state) do
    reply(state, state)
  end

  def handle_cast(:clear_state, _state) do
    no_reply(Game.new!())
  end

  def handle_cast({:join, player_id}, state) do
    updated_player =
      state.players[player_id]
      |> Map.put(:joined, true)

    updated_players = Map.put(state.players, player_id, updated_player)

    Map.put(state, :players, updated_players)
    |> no_reply()
  end

  def handle_cast({:place_bet, player_id, wager, ready}, state = %{state: :waiting}) do
    previous_wager = state.players[player_id].wager

    updated_player =
      state.players[player_id]
      |> Map.put(:ready, ready)
      |> Map.update!(:credits, &(&1 + previous_wager - wager))
      |> Map.put(:wager, wager)

    updated_players = Map.put(state.players, player_id, updated_player)

    Map.put(state, :players, updated_players)
    |> no_reply()
  end

  def handle_cast({:place_bet, _player_id, _wager, _ready}, state = %{state: :in_progress}) do
    Logger.error("Unable to place bets while game is in progress")
    no_reply(state)
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
    broadcast(state)
    state
  end

  defp broadcast(state), do: CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", state)
end
