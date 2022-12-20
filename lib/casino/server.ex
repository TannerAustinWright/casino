defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.

  If everyone busts, then dealer should not play
  theres an intermittent random error on assigning a new player.

  iex --name casino -S  mix phx.server
  iex --name tanner

    import Casino
    tid = "tanner" |> create_player() |> Map.get(:id)
    join(tid)
    bet(tid, 100)

    fid = "frank" |> create_player() |> Map.get(:id)
    join(fid)
    bet(fid, 100)

    bet(tid, 100); bet(fid, 100)

    jid = "jordan" |> create_player() |> Map.get(:id)
    join(jid)
    bet(jid, 250)

    vid = "talin" |> create_player() |> Map.get(:id)
    join(vid)
    bet(vid, 500)


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
    # |> Map.put(:timeout, send_after(seconds: @betting_time_seconds, :timeout))
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
    |> broadcast()
    |> no_reply()
  end

  ###
  # In Progress
  #

  def handle_cast({:hit, player_id}, game) when player_id === game.active_player do
    game
    |> Game.hit_player()
    |> Game.play_dealer()
    |> Game.payout(fn ->
      send_after(seconds(@betting_time_seconds), :timeout)
    end)
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:hit, player_id}, game) when game.state === :in_progress do
    Logger.error("Player #{player_id} tried to hit when it was not their turn.")
    no_reply(game)
  end

  def handle_cast({:hit, player_id}, game) do
    Logger.error("Player #{player_id} tried to hit during game state: #{game.state}")
    no_reply(game)
  end

  def handle_cast({:stand, player_id}, game) when player_id === game.active_player do
    game
    |> Game.player_stand()
    |> Game.play_dealer()
    |> Game.payout(fn ->
      send_after(seconds(@betting_time_seconds), :timeout)
    end)
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:stand, player_id}, game) do
    Logger.error(
      "Player #{game.players[player_id].name} tried to stand when it was not their turn."
    )

    no_reply(game)
  end

  def handle_cast({:double_down, player_id}, game) when player_id === game.active_player do
    hand_length = length(game.players[game.active_player].hands[game.active_hand].cards)

    if hand_length === 2 do
      game
      |> Game.double_down()
      |> Game.play_dealer()
      |> Game.payout(fn ->
        send_after(seconds(@betting_time_seconds), :timeout)
      end)
      |> broadcast()
      |> no_reply()
    else
      Logger.error("Player #{game.players[player_id].name} tried to double down after hitting.")
      no_reply(game)
    end
  end

  def handle_cast({:double_down, player_id}, game) do
    Logger.error(
      "Player #{game.players[player_id].name} tried to double down when it was not their turn."
    )

    no_reply(game)
  end

  def handle_cast({:split, player_id}, game) when player_id === game.active_player do
    game
    |> Game.split_hand()
    |> Game.play_dealer()
    |> Game.payout(fn ->
      send_after(seconds(@betting_time_seconds), :timeout)
    end)
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:split, player_id}, game) when game.state === :in_progress do
    Logger.error("Player #{player_id} tried to split when it was not their turn.")
    no_reply(game)
  end

  def handle_cast({:split, player_id}, game) do
    Logger.error("Player #{player_id} tried to split during game state: #{game.state}")
    no_reply(game)
  end

  ###
  # Multi-State Handlers
  #

  def handle_cast({:bet, player_id, wager}, game) when game.state === :taking_bets do
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
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:buy_insurance, player_id, wants_insurance}, game)
      when game.state === :insurance do
    game
    |> Game.bet_insurance(player_id, wants_insurance)
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:set_ready, player_id, ready}, game)
      when game.state in [:taking_bets, :insurance] do
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

  def handle_info(:timeout, game) when game.state === :shuffling do
    game
    |> Game.clear_table(fn ->
      send_after(seconds(@betting_time_seconds), :timeout)
    end)
    |> broadcast()
    |> no_reply()
  end

  def handle_info(:timeout, game) when game.state === :taking_bets do
    # game
    # |> Game.handle_timeout()
    # |> broadcast()
    # |> no_reply()

    if Game.one_wager?(game) do
      Logger.info("Game starting...")

      game
      |> Game.deal(fn ->
        send_after(seconds(@betting_time_seconds), :timeout)
      end)
      |> broadcast()
      |> no_reply()
    else
      Logger.warn(
        "No players have placed bets. Starting #{@betting_time_seconds} second timer over."
      )

      send_after(seconds(@betting_time_seconds), :timeout)
      no_reply(game)
    end
  end

  def handle_info(:timeout, game) when game.state === :insurance do
    game
    |> Game.handle_insurance(fn ->
      send_after(seconds(@betting_time_seconds), :timeout)
    end)
    |> broadcast()
    |> no_reply()
  end

  def handle_info(message, state) do
    Logger.warn("Received unhandled info: #{message}")

    no_reply(state)
  end

  defp broadcast(game) do
    CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", game)
    BlackJack.Game.show(game)
  end

  # def broadcast(game), do: BlackJack.Game.show(game)
end
