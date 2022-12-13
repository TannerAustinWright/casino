defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.

    import Casino
    import BlackJack.Game
    fid = "frank" |> create_player() |> Map.get(:id)
    tid = "tanner" |> create_player() |> Map.get(:id)
    join(tid)
    join(fid)
    place_bet(tid, 250, true)
    place_bet(fid, 500, false)

   print_cards get_state

  """
  use Casino.GenServer
  require Logger

  alias BlackJack.{
    Game,
    Player
  }

  @betting_time_seconds 10

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
    update_in(game.start_game_scheduled_message, fn
      nil ->
        nil

      scheduled_message ->
        Process.cancel_timer(scheduled_message)
    end)

    game_with_player = put_in(game.players[player_id].joined, true)

    update_in(game_with_player.state, fn
      :idle ->
        :taking_bets

      other_state ->
        other_state
    end)
    |> Map.put(
      :start_game_scheduled_message,
      send_message_after(seconds(@betting_time_seconds), :start_game)
    )
    |> no_reply()
  end

  def handle_cast({:place_bet, player_id, wager, ready}, game = %{state: :taking_bets}) do
    previous_hand = Player.initial_hand(game.players[player_id])
    previous_wager = previous_hand.wager

    updated_player =
      game.players[player_id]
      |> Map.put(:ready, ready)
      |> Map.update!(:credits, &(&1 + previous_wager - wager))
      |> Map.put(:valid_wager, wager >= game.minimum_wager)

    modified_hand = put_in(previous_hand.wager, wager)
    player_with_updated_wager = put_in(updated_player.hands, %{modified_hand.id => modified_hand})

    updated_players = Map.put(game.players, player_id, player_with_updated_wager)

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
    game
    |> Game.hit_player()
    |> Game.play_dealer()
    |> Game.payout_clear_wagers(fn ->
      send_message_after(seconds(@betting_time_seconds), :start_game)
    end)
    |> no_reply()
  end

  def handle_cast({:hit, player_id}, game) do
    Logger.error("Player #{player_id} tried to hit when it was not their turn.")
    no_reply(game)
  end

  def handle_cast({:stand, player_id}, game) when player_id === game.active_player do
    game
    |> Game.player_stand()
    |> Game.play_dealer()
    |> Game.payout_clear_wagers(fn ->
      send_message_after(seconds(@betting_time_seconds), :start_game)
    end)
    |> no_reply()
  end

  def handle_cast({:stand, player_id}, game) do
    Logger.error("Player #{player_id} tried to stand when it was not their turn.")
    no_reply(game)
  end

  def handle_cast({:double_down, _player_id}, game) do
    game
  end

  def handle_cast({:surrender, _player_id}, game) do
    broadcast(game)
    game
  end

  def handle_info(:start_game, game = %{state: :taking_bets}) do
    if Game.one_wager?(game) do
      Logger.info("Game starting...")

      game
      |> Game.deal()
      |> no_reply()
    else
      Logger.warn(
        "No players have placed bets. Starting #{@betting_time_seconds} second timer over."
      )

      send_message_after(seconds(@betting_time_seconds), :start_game)
      no_reply(game)
    end
  end

  def handle_info(_message, state) do
    Logger.warn("Received unhandled info...")

    no_reply(state)
  end

  def count_down(ms) do
    Process.spawn(
      fn ->
        Enum.each(div(ms, 1_000)..0, fn count ->
          IO.inspect(count)
          :timer.sleep(seconds(1))
        end)
      end,
      [:monitor]
    )

    ms
  end

  defp broadcast(game), do: CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", game)
end
