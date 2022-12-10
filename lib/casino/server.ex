defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.

    id = "frank" |> Casino.create_player() |> Map.get(:id)
    Casino.join(id)
    Casino.place_bet(id, 100, true)

  """
  use Casino.GenServer
  require Logger

  alias BlackJack.{
    Game,
    Player
  }

  def start_link(options \\ []),
    do: GenServer.start_link(__MODULE__, %{}, options)

  def init(_state), do: {:ok, Game.new!()}

  def handle_call({:get_player, player_id}, _from, game) do
    game
    |> Game.get_player(player_id)
    |> reply(game)
  end

  def handle_call({:create_player, name}, _from, game) do
    player = Player.new!(name: name)

    reply(player, Game.create_player(game, player))
  end

  def handle_call(:get_state, _from, game) do
    reply(game, game)
  end

  def handle_cast(:clear_state, _game) do
    no_reply(Game.new!())
  end

  def handle_cast({:join, player_id}, game) do
    updated_player =
      game.players[player_id]
      |> Map.put(:joined, true)

    updated_players = Map.put(game.players, player_id, updated_player)

    {updated_game, timeout} =
      if game.state === :idle,
        do: {Map.put(game, :state, :taking_bets), 5},
        else: {game, nil}

    updated_game
    |> Map.put(:players, updated_players)
    |> nr_and_queue_message(:start_game, count_down(timeout))
  end

  def handle_cast({:place_bet, player_id, wager, ready}, game = %{state: :taking_bets}) do
    previous_wager = game.players[player_id].wager

    updated_player =
      game.players[player_id]
      |> Map.put(:ready, ready)
      |> Map.update!(:credits, &(&1 + previous_wager - wager))
      |> Map.put(:wager, wager)

    updated_players = Map.put(game.players, player_id, updated_player)

    Map.put(game, :players, updated_players)
    |> no_reply()
  end

  def handle_cast({:place_bet, _player_id, _wager, _ready}, game = %{state: state}) do
    Logger.error("Unable to place bets while game is in #{state}")
    no_reply(game)
  end

  def handle_cast({:buy_insurance, _player_id, _wager, _ready}, game) do
    no_reply(game, nil)
  end

  def handle_cast({:split, _player_id, _split}, game) do
    game
  end

  def handle_cast({:hit, player_id}, game) when player_id === game.active_player do
    no_reply Game.hit(game)
  end

  def handle_cast({:hit, player_id}, state) do
    Logger.error("Player #{player_id} tried to hit when it was not their turn.")
    no_reply(state)
  end

  def handle_cast({:stand, _player_id}, game) do
    game
  end

  def handle_cast({:double_down, _player_id}, game) do
    game
  end

  def handle_cast({:surrender, _player_id}, game) do
    broadcast(game)
    game
  end

  ###
  # handle info
  #
  # def handle_info(:timeout, game = %{state: :taking_bets}) do
  #   game
  #   |> Game.deal()
  #   |> no_reply()
  # end

  def handle_info(:start_game, game = %{state: :taking_bets}) do
    game
    |> Game.deal()
    |> no_reply()
  end

  def handle_info(_message, state) do
    Logger.warn("Received unhandled info...")

    no_reply(state)
  end

  def count_down(seconds) do
    # Process.spawn(
    #   fn ->
    #     Enum.each(seconds..0, fn count ->
    #       IO.inspect(count)
    #       :timer.sleep(seconds(1))
    #     end)
    #   end,
    #   [:monitor]
    # )

    seconds(seconds)
  end

  defp broadcast(game), do: CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", game)
end
