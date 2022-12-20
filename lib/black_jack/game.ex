defmodule BlackJack.Game do
  @moduledoc """
  states:
    idle  -   no players are in the server
    taking_bets   -   players are in the server, timeout has been set to start game
  """
  require Logger

  alias BlackJack.{
    Deck,
    Hand,
    Player
  }

  @ten_values ["10", "jack", "queen", "king"]

  defstruct [
    :state,
    :minimum_wager,
    :dealer_hand,
    :active_player,
    :active_hand,
    :players,
    :next_position,
    :deck,
    :timeout
  ]

  @deck_count 3

  # @betting_states [
  #   :taking_bets,
  #   :insurance
  # ]

  # @timed_states [
  #   :taking_bets,
  #   :insurance,
  #   :shuffling
  # ]

  # @states [
  #   :idle,
  #   :taking_bets,
  #   :insurance,
  #   :in_progress,
  #   :shuffling
  # ]

  @defaults [
    next_position: 0,
    state: :idle,
    minimum_wager: 20,
    deck: [],
    players: %{}
  ]

  def new!(params \\ [])

  def new!(params) when is_list(params) do
    params_with_defaults =
      @defaults
      |> Keyword.merge(deck: Deck.new(@deck_count))
      |> Keyword.merge(params)

    struct!(__MODULE__, params_with_defaults)
  end

  def new!(params) when is_map(params) do
    params
    |> Map.to_list()
    |> new!()
  end

  def get_player(game, player_id) do
    game.players[player_id]
  end

  def add_player(game, player) do
    update_in(game.players[player.id], fn
      nil ->
        Map.put(player, :position, game.next_position)

      other ->
        other
    end)
    |> Map.update!(:next_position, &(&1 + 1))
  end

  def set_player_ready(game, _player_id, _ready) do
    game
  end

  def deal(game, fun) do
    game_with_hands =
      game.players
      |> Enum.reduce(game, fn
        {_player_id, %{valid_wager: false}}, game ->
          game

        {player_id, _player}, game ->
          {hand, deck} = Hand.deal(game.deck)

          initial_hand = Player.initial_hand(game.players[player_id])

          put_in(
            game.players[player_id].hands[initial_hand.id],
            Hand.new!(
              wager: initial_hand.wager,
              id: initial_hand.id,
              value: hand.value,
              complete: hand.complete,
              cards: hand.cards
            )
          )
          |> Map.put(:deck, deck)
      end)

    {dealer_hand, deck} = Hand.deal(game_with_hands.deck, :dealer)

    game_with_dealer_hand =
      game_with_hands
      |> Map.put(:dealer_hand, dealer_hand)
      |> Map.put(:deck, deck)

    handle_insurance(game_with_dealer_hand, fun)
  end

  def handle_insurance(game, fun) do
    case game do
      # dealer has blackjack without insurance
      %{dealer_hand: %{cards: [%{value: "ace"}, %{value: value}]}, state: :taking_bets}
      when value in @ten_values ->
        payout(game, fun)

      # dealer is showing ace so go to insurance
      %{
        dealer_hand: %{cards: [_face_down, %{face_down: false, value: "ace"}]},
        state: :taking_bets
      } ->
        fun.()
        Map.put(game, :state, :insurance)

      # insurance has been collected and the dealer has blackjack
      %{dealer_hand: %{cards: [%{value: value}, %{value: "ace"}]}, state: :insurance}
      when value in @ten_values ->
        payout(game, fun)

      # insurance may have been collected, and the dealer does not have blackjack
      %{state: state} when state in [:taking_bets, :insurance] ->
        game
        |> update_active_player()
        |> Map.put(:state, :in_progress)
    end
  end

  def update_active_player(game = %{active_player: nil, active_hand: nil}) do
    game_with_new_active_player =
      Map.put(game, :active_player, next_active_player_id(game.players))

    Map.put(
      game_with_new_active_player,
      :active_hand,
      next_active_hand_id(
        game_with_new_active_player.players[game_with_new_active_player.active_player]
      )
    )
    |> check_new_hand_blackjack()
  end

  def update_active_player(game) do
    hand = game.players[game.active_player].hands[game.active_hand]

    # no active player, or hand
    cond do
      # current player needs to finish their current hand
      not hand.complete ->
        game

      # current player needs to finish other incomplete hands
      not is_nil(next_active_hand_id(game.players[game.active_player])) ->
        Map.put(
          game,
          :active_hand,
          next_active_hand_id(game.players[game.active_player])
        )

      # other players need to complete their hands
      not is_nil(next_active_player_id(game.players)) ->
        game_with_new_active_player =
          Map.put(game, :active_player, next_active_player_id(game.players))

        Map.put(
          game_with_new_active_player,
          :active_hand,
          next_active_hand_id(
            game_with_new_active_player.players[game_with_new_active_player.active_player]
          )
        )

      # all hands complete
      true ->
        game
        |> Map.put(:active_player, nil)
        |> Map.put(:active_hand, nil)
    end
    |> check_new_hand_blackjack()
  end

  def check_new_hand_blackjack(game = %{active_player: nil, active_hand: nil}), do: game

  def check_new_hand_blackjack(game = %{active_player: player, active_hand: hand}) do
    wager = game.players[player].hands[hand].wager

    if Hand.black_jack?(game.players[player].hands[hand]) do
      update_in(game.players[player], fn player ->
        player
        |> Map.update!(:credits, &(&1 + floor(wager * 2.5)))
        |> Map.update!(:hands, &Map.delete(&1, hand))
      end)
      |> update_active_player()
    else
      game
    end
  end

  def bet_insurance(game, player_id, wants_insurance) do
    [{_hand_id, hand}] = Map.to_list(game.players[player_id].hands)

    update_in(game.players[player_id], fn player ->
      player
      |> Map.put(:insurance, wants_insurance)
      |> Map.update!(:credits, fn credits ->
        cond do
          wants_insurance and not player.insurance ->
            credits - div(hand.wager, 2)

          not wants_insurance and player.insurance ->
            credits + div(hand.wager, 2)

          true ->
            credits
        end
      end)
    end)
  end

  def payout(game, fun) when is_nil(game.active_player) do
    new_state =
      Enum.reduce(game.players, game, fn
        {player_id, player = %{valid_wager: true}}, game ->
          %{credits: new_credits, hands: face_up_hands} =
            Enum.reduce(player.hands, %{credits: 0, hands: player.hands}, fn
              {hand_id, player_hand}, acc ->
                case Hand.beats?(player_hand, game.dealer_hand) do
                  # player beat dealer
                  true ->
                    acc
                    |> Map.update!(:credits, &(&1 + player_hand.wager * 2))

                  # player lost
                  false ->
                    acc

                  # push
                  nil ->
                    acc
                    |> Map.update!(:credits, &(&1 + player_hand.wager))
                end
                |> Map.update!(:credits, fn credits ->
                  insurance_payout = if player.insurance, do: 2 * player_hand.wager, else: 0

                  if Hand.black_jack?(game.dealer_hand),
                    do: credits + insurance_payout,
                    else: credits
                end)
                |> Map.update!(:hands, fn hands ->
                  face_up_hand =
                    update_in(player_hand.cards, fn cards ->
                      Enum.map(cards, &Map.put(&1, :face_down, false))
                    end)

                  Map.put(hands, hand_id, face_up_hand)
                end)
            end)

          update_in(game.players[player_id], fn player ->
            player
            |> Map.update!(:credits, &(&1 + new_credits))
            |> Map.put(:hands, face_up_hands)
            |> Map.put(:insurance, false)
          end)

        {_player_id, _player}, game ->
          game
      end)
      |> Map.update!(:dealer_hand, fn dealer ->
        update_in(dealer.cards, fn cards ->
          Enum.map(cards, &Map.put(&1, :face_down, false))
        end)
      end)
      |> Map.put(:state, :shuffling)

    fun.()

    new_state
  end

  def payout(game, _fun), do: game

  def clear_table(game, fun) when is_nil(game.active_player) do
    new_state =
      Enum.reduce(game.players, game, fn
        {player_id, %{valid_wager: true}}, game ->
          update_in(game.players[player_id], fn player ->
            player
            |> Map.put(:ready, false)
            |> Map.put(:hands, %{})
            |> Map.put(:insurance, false)
            |> Map.put(:valid_wager, false)
          end)

        {_player_id, _player}, game ->
          game
      end)
      |> Map.put(:dealer_hand, nil)
      |> Map.put(:state, :taking_bets)

    fun.()
    new_state
  end

  # if deck < 30% after a round reset deck
  # blackjack doesnt immediately pay out and it should pay out 1.5x bet

  def play_dealer(game) when is_nil(game.active_player) do
    case game.dealer_hand.value do
      # dealer hits on soft 17
      [greater_value | _lesser_value] when greater_value <= 17 ->
        hit_dealer(game)

      # dealer hits on 16
      [value] when value < 17 ->
        hit_dealer(game)

      _dealer_stands ->
        update_in(game.dealer_hand.complete, fn _ -> true end)
    end
  end

  def play_dealer(game), do: game

  def double_down(game) do
    old_deck = game.deck
    old_hand = game.players[game.active_player].hands[game.active_hand]
    {deck, hand} = Hand.double_down(old_deck, old_hand)

    game_with_deck = Map.put(game, :deck, deck)

    update_in(game_with_deck.players[game.active_player], fn player ->
      player_with_credits = Map.update!(player, :credits, &(&1 - hand.wager))

      update_in(player_with_credits.hands[game.active_hand], fn _ ->
        Map.put(hand, :wager, hand.wager * 2)
      end)
    end)
    |> update_active_player()
  end

  def hit_dealer(game) do
    {new_deck, new_dealer_hand} = Hand.hit(game.deck, game.dealer_hand)

    game
    |> Map.put(:deck, new_deck)
    |> Map.put(:dealer_hand, new_dealer_hand)
    |> play_dealer()
  end

  def hit_player(game) do
    {deck, hand} = Hand.hit(game.deck, game.players[game.active_player].hands[game.active_hand])

    game_with_deck = Map.put(game, :deck, deck)

    put_in(game_with_deck.players[game.active_player].hands[game.active_hand], hand)
    |> update_active_player()
  end

  def next_active_player_id(players) do
    players
    |> Enum.filter(&(not is_nil(next_active_hand_id(elem(&1, 1)))))
    |> Enum.min_by(&elem(&1, 1).position, fn -> nil end)
    |> case do
      nil ->
        nil

      {player_id, _hand} ->
        player_id
    end
  end

  def next_active_hand_id(player) do
    player.hands
    |> Enum.filter(&(not elem(&1, 1).complete))
    |> List.first()
    |> case do
      nil ->
        nil

      {hand_id, _hand} ->
        hand_id
    end
  end

  def player_stand(game) do
    put_in(game.players[game.active_player].hands[game.active_hand].complete, true)
    |> update_active_player()
  end

  def show(game) when not is_nil(game.dealer_hand) do
    IO.inspect(state: game.state)
    IO.inspect("Dealer:")

    if not Enum.any?(game.dealer_hand.cards, & &1.face_down),
      do: IO.inspect(BlackJack.Hand.max_value(game.dealer_hand))

    Enum.each(game.dealer_hand.cards, fn
      %{value: value, face_down: false} ->
        IO.inspect(" - #{value}")

      _ ->
        IO.inspect("*****")
    end)

    Enum.each(game.players, fn
      {_player_id, player = %{valid_wager: true}} ->
        active_indicator = if game.active_player === player.id, do: ">>> ", else: ""

        IO.inspect("#{active_indicator}#{player.name} (#{player.credits}):")

        Enum.each(player.hands, fn {_hand_id, hand = %{cards: cards}} ->
          if not Enum.any?(cards, & &1.face_down), do: IO.inspect(BlackJack.Hand.max_value(hand))

          Enum.each(cards, fn
            %{value: value, face_down: false} ->
              IO.inspect(" - #{value}")

            _ ->
              IO.inspect("*****")
          end)
        end)

      _other ->
        nil
    end)

    if game.state === :insurance, do: IO.inspect("Would you like to buy insurance?")

    game
  end

  def show(game) when game.state === :taking_bets do
    IO.inspect("Place your bets. $#{game.minimum_wager} minimum wager.")
    game
  end

  def show(game) do
    Logger.warn("Unhandled show in state: #{game.state}")
    game
  end

  def one_wager?(game),
    do: Enum.any?(game.players, &elem(&1, 1).valid_wager)
end
