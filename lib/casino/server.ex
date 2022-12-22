defmodule Casino.Server do
  @moduledoc """
  The server layer for the casino module.

  iex --name casino -S  mix phx.server
  iex --name tanner

  /game-floor npm start
  /casino iex -S mix phx.server

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

  alias BlackJack.Game

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

  def handle_call({:upsert_player, player_params}, _from, game) do
    {player, game} = Game.upsert_player(game, player_params)

    broadcast(game)

    reply(player, game)
  end

  def handle_call(:get_state, _from, game) do
    reply(game, game)
  end

  def handle_cast(:clear_state, _game) do
    Game.new!()
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:join, player_id}, game) when game.state not in [:idle, :taking_bets] do
    game
    |> Game.join(player_id)
    |> broadcast()
    |> no_reply()
  end

  ###
  # Idle
  #

  def handle_cast({:join, player_id}, game) when game.state in [:idle, :taking_bets] do
    game
    |> Game.join(player_id)
    |> set_timeout_for_state()
    |> broadcast()
    |> no_reply()
  end

  ###
  # In Progress
  #

  def handle_cast({:hit, player_id}, game) when player_id === game.active_player do
    game
    |> Game.hit_active_player()
    |> set_timeout_for_state()
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:stand, player_id}, game) when player_id === game.active_player do
    game
    |> Game.stand_active_player()
    |> set_timeout_for_state()
    |> broadcast()
    |> no_reply()
  end

  def handle_cast({:double_down, player_id}, game) when player_id === game.active_player do
    if Game.active_player_can_double_down?(game) do
      game
      |> Game.double_down_active_player()
      |> set_timeout_for_state()
      |> broadcast()
      |> no_reply()
    else
      no_reply(game)
    end
  end

  def handle_cast({:split, player_id}, game) when player_id === game.active_player do
    if Game.active_player_can_split?(game) do
      game
      |> Game.split_active_player()
      |> set_timeout_for_state()
      |> broadcast()
      |> no_reply()
    else
      no_reply(game)
    end
  end

  ###
  # Taking Bets
  #

  def handle_cast({:bet, player_id, wager}, game) when game.state === :taking_bets do
    game
    |> Game.set_wager(player_id, wager)
    |> broadcast()
    |> no_reply()
  end

  ###
  # Insurance
  #

  def handle_cast({:buy_insurance, player_id, wants_insurance}, game)
      when game.state === :insurance do
    if Game.is_playing?(game, player_id) do
      game
      |> Game.bet_insurance(player_id, wants_insurance)
      |> broadcast()
      |> no_reply()
    else
      no_reply(game)
    end
  end

  def handle_cast({:set_ready, player_id, ready}, game)
      when game.state in [:taking_bets, :insurance] do
    game
    |> Game.set_player_ready(player_id, ready)
    |> broadcast()
    |> no_reply()
  end

  def handle_cast(cast_tuple, game) do
    Logger.error(
      "Unable to complete action '#{elem(cast_tuple, 0)}' while game is in state '#{game.state}'"
    )

    no_reply(game)
  end

  ###
  # Timer Handlers
  #

  def handle_info(:shuffling_timeout, game) when game.state === :shuffling do
    game
    |> Game.clear_table()
    |> set_timeout_for_state()
    |> broadcast()
    |> no_reply()
  end

  def handle_info(:taking_bets_timeout, game) when game.state === :taking_bets do
    if Game.one_wager?(game) do
      game
      |> Game.deal()
      |> set_timeout_for_state()
      |> broadcast()
      |> no_reply()
    else
      Logger.warn(
        "No players have placed bets. Starting #{@betting_time_seconds} second timer over."
      )

      game
      |> set_timeout_for_state()
      |> no_reply()
    end
  end

  def handle_info(:insurance_timeout, game) when game.state === :insurance do
    game
    |> Game.handle_insurance()
    |> set_timeout_for_state()
    |> broadcast()
    |> no_reply()
  end

  def handle_info(message, game) do
    Logger.warn("Received unhandled info: #{message} in state #{inspect(game.state)}")

    no_reply(game)
  end

  defp set_timeout_for_state(state = %{state: :insurance}) do
    send_after(seconds(@betting_time_seconds), :insurance_timeout)
    state
  end

  defp set_timeout_for_state(state = %{state: :shuffling}) do
    send_after(seconds(@betting_time_seconds), :shuffling_timeout)
    state
  end

  defp set_timeout_for_state(state = %{state: :taking_bets}) do
    Map.update!(state, :betting_timeout, fn
      nil ->
        send_after(seconds(@betting_time_seconds), :taking_bets_timeout)

      betting_timeout ->
        Process.cancel_timer(betting_timeout)
        send_after(seconds(@betting_time_seconds), :taking_bets_timeout)
    end)
  end

  defp set_timeout_for_state(state), do: state

  defp broadcast(game) do
    CasinoWeb.Endpoint.broadcast("game:lobby", "state_update", game)
    BlackJack.Game.show(game)
  end
end
