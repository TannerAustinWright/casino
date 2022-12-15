defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.

    import Casino
    import BlackJack.Game
    fid = "frank" |> create_player() |> Map.get(:id)
    tid = "tanner" |> create_player() |> Map.get(:id)
    join(tid)
    join(fid)
    bet(tid, 250)
    bet(fid, 500)

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

  ###
  # Stateless Actions
  #

  def handle_call({:get_player, player_id}, _from, game) do
    game
    |> Game.get_player(player_id)
    |> reply(game)
  end

  def handle_call({:create_player, name}, _from, game) do
    player = Player.new!(name: name)

    game_with_player =
      game
      |> Game.add_player(player)
      |> broadcast()

    reply(player, game_with_player)
  end

  def handle_call(:get_state, _from, game) do
    reply(game, game)
  end

  def handle_cast(:clear_state, _game) do
    Game.new!()
    |> broadcast()
    |> no_reply()
  end

  # def handle_cast({:join, player_id}, game) when game.state !== :idle do
  #   game
  #   |> Game.player_joined(player_id)
  #   |> broadcast()
  #   |> no_reply()
  # end

  ###
  # Idle
  #

  def handle_cast({:join, player_id}, game) when game.state in [:idle, :taking_bets] do
    # game
    # |> Map.update(:timer, nil, & Process.cancel_timer(&1))
    # |> Game.player_joined(player_id)
    # |> Map.put(:timeout, send_after(seconds: @betting_time_seconds, :start_game))
    # |> broadcast()
    # |> no_reply()

    Map.update!(game, :timeout, fn
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
      :timeout,
      send_after(seconds(@betting_time_seconds), :timeout)
    )
    |> no_reply()
  end

  ###
  # In Progress
  #

  def handle_cast({:hit, player_id}, game) when player_id === game.active_player do
    game
    |> Game.hit_player()
    |> Game.play_dealer()
    |> Game.payout_clear_wagers(fn ->
      send_after(seconds(@betting_time_seconds), :start_game)
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
      send_after(seconds(@betting_time_seconds), :start_game)
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

  def handle_cast({:split, _player_id, _split}, game) do
    game
  end

  ###
  # Multi-State Handlers
  #

  def handle_cast({:bet, player_id, wager}, game) when game.state in [:taking_bets, :insurance] do
    # game
    # |> Game.update_wager(player_id, wager)
    # |> broadcast()
    # |> no_reply()

    previous_hand = Player.initial_hand(game.players[player_id])
    previous_wager = previous_hand.wager

    updated_player =
      game.players[player_id]
      |> Map.update!(:credits, &(&1 + previous_wager - wager))
      |> Map.put(:valid_wager, wager >= game.minimum_wager)

    modified_hand = put_in(previous_hand.wager, wager)
    player_with_updated_wager = put_in(updated_player.hands, %{modified_hand.id => modified_hand})

    updated_players = Map.put(game.players, player_id, player_with_updated_wager)

    Map.put(game, :players, updated_players)
    |> no_reply()
  end

  def handle_cast({:set_ready, player_id, ready}, game) when game.state in [:taking_bets, :insurance] do
    game
    |> Game.set_player_ready(player_id, ready)
    |> broadcast()
    |> no_reply()
  end

  # catch all
  def handle_cast(cast_tuple, game) do
    Logger.error(
      "Unable to complete action '#{elem(cast_tuple, 0)}' while game is in state '#{game.state}'"
    )

    no_reply(game)
  end

  ###
  # Timer Handlers
  #

  def handle_info(:timeout, game) when game.state in [:taking_bets, :insurance] do
    # game
    # |> Game.handle_timeout()
    # |> broadcast()
    # |> no_reply()

    if Game.one_wager?(game) do
      Logger.info("Game starting...")

      game
      |> Game.deal()
      |> no_reply()
    else
      Logger.warn(
        "No players have placed bets. Starting #{@betting_time_seconds} second timer over."
      )

      send_after(seconds(@betting_time_seconds), :timeout)
      no_reply(game)
    end
  end

  # catch all
  def handle_info(message, state) do
    Logger.warn("Received unhandled info: #{message}")

    no_reply(state)
  end

  # defp broadcast(game), do: CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", game)
  def broadcast(game) do
    keys_to_remove = [
      :deck,
      :discard
    ]

    IO.inspect(Map.drop(game, keys_to_remove))

    game
  end

  ###
  # utility
  #

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
end
