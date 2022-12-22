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

  @derive {Jason.Encoder, [except: [:betting_timeout, :deck]]}
  defstruct [
    :state,
    :minimum_wager,
    :dealer_hand,
    :active_player,
    :active_hand,
    :players,
    :next_position,
    :deck,
    :betting_timeout
  ]

  @ten_values ["10", "jack", "queen", "king"]
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

  def upsert_player(game, player_params = %{id: player_id}) do
    game_after_upsert =
      update_in(game.players[player_id], fn
        nil ->
          player_params
          |> Player.new!()
          |> Map.put(:position, game.next_position)

        existing_player ->
          Map.merge(existing_player, player_params)
      end)

    new_player = game_after_upsert.players[player_id]

    if map_size(game.players) !== map_size(game_after_upsert.players) do
      {new_player, Map.update!(game_after_upsert, :next_position, &(&1 + 1))}
    else
      {new_player, game_after_upsert}
    end
  end

  def upsert_player(game, player_params) do
    new_player =
      player_params
      |> Player.new!()
      |> Map.put(:position, game.next_position)

    new_state =
      put_in(game.players[new_player.id], new_player)
      |> Map.update!(:next_position, &(&1 + 1))

    {new_player, new_state}
  end

  def join(game, player_id) do
    if player_id in Map.keys(game.players) do
      game_with_player = put_in(game.players[player_id].joined, true)

      update_in(game_with_player.state, fn
        :idle ->
          :taking_bets

        other_state ->
          other_state
      end)
    else
      Logger.error("Player #{player_id} tried to join but does not exist.")
      game
    end
  end

  def set_wager(game, player_id, wager) do
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
  end

  def active_player_can_double_down?(game = %{active_player: player, active_hand: hand}),
    do: length(game.players[player].hands[hand].cards) === 2

  def set_player_ready(game, _player_id, _ready) do
    game
  end

  def deal(game) do
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

    handle_insurance(game_with_dealer_hand)
  end

  def handle_insurance(game) do
    case game do
      # dealer has blackjack without insurance
      %{dealer_hand: %{cards: [%{value: "ace"}, %{value: value}]}, state: :taking_bets}
      when value in @ten_values ->
        payout(game)

      # dealer is showing ace so go to insurance
      %{
        dealer_hand: %{cards: [_face_down, %{face_down: false, value: "ace"}]},
        state: :taking_bets
      } ->
        Map.put(game, :state, :insurance)

      # insurance has been collected and the dealer has blackjack
      %{dealer_hand: %{cards: [%{value: value}, %{value: "ace"}]}, state: :insurance}
      when value in @ten_values ->
        payout(game)

      # insurance may have been collected, and the dealer does not have blackjack
      %{state: state} when state in [:taking_bets, :insurance] ->
        game
        |> update_active_player()
        |> Map.put(:state, :in_progress)
    end
  end

  def update_active_player(game = %{active_player: nil, active_hand: nil}) do
    next_player = next_active_player_id(game.players)

    game
    |> Map.put(:active_player, next_player)
    |> Map.put(:active_hand, next_active_hand_id(game.players[next_player]))
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
    number_of_hands = map_size(game.players[player].hands)

    Logger.warn(
      "Checking if player has blackjack: #{
        Hand.black_jack?(game.players[player].hands[hand]) and number_of_hands === 1
      }"
    )

    if Hand.black_jack?(game.players[player].hands[hand]) and number_of_hands === 1 do
      Logger.warn("Player had blackjack!")

      update_in(game.players[player], fn player ->
        put_in(player.hands[hand].wager, 0)
        |> Map.update!(:credits, &(&1 + div(5 * wager, 2)))
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

  def payout(game) when is_nil(game.active_player) do
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
                  insurance_payout =
                    if player.insurance, do: div(3 * player_hand.wager, 2), else: 0

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
      |> Map.put(:active_player, nil)
      |> Map.put(:active_hand, nil)
      |> Map.put(:state, :shuffling)
      |> Map.update!(:deck, fn deck ->
        if length(deck) / @deck_count * 52 < 0.3 do
          Deck.new(@deck_count)
        else
          deck
        end
      end)

    new_state
  end

  def payout(game), do: game

  def clear_table(game) when is_nil(game.active_player) do
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

    new_state
  end

  # if deck < 30% after a round reset deck
  # blackjack doesnt immediately pay out and it should pay out 1.5x bet

  def play_dealer(game) when is_nil(game.active_player) do
    any_players_remain? =
      Enum.any?(game.players, fn {_player_id, player} ->
        Enum.any?(
          player.hands,
          fn {_hand_id, hand} ->
            not (Hand.bust?(hand) or (Hand.black_jack?(hand) and map_size(player.hands) === 1))
          end
        )
      end)

    # if all players have all busted hands and blackjacks with one hand

    case game.dealer_hand.value do
      # dealer hits on soft 17
      [greater_value | _lesser_value] when greater_value <= 17 and any_players_remain? ->
        hit_dealer(game)

      # dealer hits on 16
      [value] when value < 17 and any_players_remain? ->
        hit_dealer(game)

      _dealer_stands ->
        update_in(game.dealer_hand.complete, fn _ -> true end)
        |> payout()
    end
  end

  def play_dealer(game), do: game

  def hit_dealer(game) do
    {new_deck, new_dealer_hand} = Hand.hit(game.deck, game.dealer_hand)

    game
    |> Map.put(:deck, new_deck)
    |> Map.put(:dealer_hand, new_dealer_hand)
    |> play_dealer()
  end

  def double_down_active_player(game) do
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
    |> play_dealer()
  end

  def hit_active_player(game) do
    {deck, hand} = Hand.hit(game.deck, game.players[game.active_player].hands[game.active_hand])

    game_with_deck = Map.put(game, :deck, deck)

    put_in(game_with_deck.players[game.active_player].hands[game.active_hand], hand)
    |> update_active_player()
    |> play_dealer()
  end

  def is_playing?(game, player_id), do: game.players[player_id].valid_wager

  def active_player_can_split?(game = %{active_player: player, active_hand: hand}),
    do: Hand.can_split?(game.players[player].hands[hand])

  def split_active_player(game = %{active_player: player, active_hand: hand}) do
    hand_to_split = game.players[player].hands[hand]

    {first_draw, deck_after_one_draw} = Deck.draw(game.deck)
    {second_draw, deck_after_two_draws} = Deck.draw(deck_after_one_draw)

    update_in(game.players[player], fn player ->
      player
      |> Map.update!(:credits, &(&1 - hand_to_split.wager))
      |> Map.update!(:hands, fn hands ->
        [first_card, second_card] = hand_to_split.cards

        is_ace? = first_card.value === "ace"

        new_hand =
          Hand.new!(
            wager: hand_to_split.wager,
            cards: [first_card, first_draw],
            complete: is_ace?
          )

        existing_hand =
          Hand.new!(
            wager: hand_to_split.wager,
            cards: [second_card, second_draw],
            id: hand_to_split.id,
            complete: is_ace?
          )

        hands
        |> Map.put(existing_hand.id, existing_hand)
        |> Map.put(new_hand.id, new_hand)
      end)
    end)
    |> Map.put(:deck, deck_after_two_draws)
    |> update_active_player()
    |> play_dealer()
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

  def stand_active_player(game) do
    put_in(game.players[game.active_player].hands[game.active_hand].complete, true)
    |> update_active_player()
    |> play_dealer()
  end

  def show(game) when not is_nil(game.dealer_hand) do
    IO.puts("Dealer:")

    if not Enum.any?(game.dealer_hand.cards, & &1.face_down),
      do: IO.puts("#{BlackJack.Hand.max_value(game.dealer_hand)}")

    Enum.each(game.dealer_hand.cards, fn
      %{value: value, face_down: false} ->
        IO.puts(" - #{value}")

      _ ->
        IO.puts("*****")
    end)

    Enum.each(game.players, fn
      {_player_id, player = %{valid_wager: true}} ->
        active_indicator = if game.active_player === player.id, do: "<<<<", else: ""

        IO.puts("#{player.name} (#{player.credits}) #{active_indicator}")

        Enum.each(player.hands, fn {_hand_id, hand = %{cards: cards}} ->
          active_indicator = if game.active_hand === hand.id, do: "<<<<", else: ""

          if not Enum.any?(cards, & &1.face_down),
            do: IO.puts("#{BlackJack.Hand.max_value(hand)} #{active_indicator}")

          Enum.each(cards, fn
            %{value: value, face_down: false} ->
              IO.puts(" - #{value}")

            _ ->
              IO.puts("*****")
          end)
        end)

      _other ->
        nil
    end)

    if game.state === :insurance, do: IO.puts("Would you like to buy insurance?")

    game
  end

  def show(game) when game.state === :taking_bets do
    IO.puts("Place your bets. $#{game.minimum_wager} minimum wager.")
    game
  end

  def show(game) do
    Logger.warn("Unhandled show in state: #{game.state}")
    game
  end

  def one_wager?(game),
    do: Enum.any?(game.players, &elem(&1, 1).valid_wager)
end
