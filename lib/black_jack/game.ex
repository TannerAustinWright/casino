defmodule BlackJack.Game do
  @moduledoc """
  states:
    idle  -   no players are in the server
    taking_bets   -   players are in the server, timeout has been set to start game
  """
  alias BlackJack.{
    Game,
    Deck,
    Hand,
    Player
  }

  defstruct [
    :state,
    :minimum_wager,
    :dealer_hand,
    :active_player,
    :active_hand,
    :players,
    :next_position,
    :deck,
    :discard,
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
    deck: Deck.new(@deck_count),
    discard: [],
    players: %{}
  ]

  def new!(params \\ [])

  def new!(params) when is_list(params) do
    struct!(__MODULE__, Keyword.merge(@defaults, params))
  end

  def new!(params) when is_map(params) do
    struct!(__MODULE__, params)
  end

  def get_player(game, player_id) do
    game.players[player_id]
  end

  def add_player(game, player) do
    game
    |> Map.from_struct()
    |> update_in([:players, player.id], fn
      nil ->
        Map.put(player, :position, game.next_position)

      other ->
        other
    end)
    |> Map.update!(:next_position, &(&1 + 1))
    |> new!()
  end

  def set_player_ready(game, _player_id, _ready) do
    game
  end

  def deal(game) do
    game_with_hands =
      game.players
      |> Enum.reduce(Map.from_struct(game), fn
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
      |> Map.put(:state, :in_progress)

    game_with_active_player =
      Map.put(game_with_hands, :active_player, next_active_player_id(game_with_hands.players))

    {dealer_hand, deck} = Hand.deal(game_with_active_player.deck, :dealer)

    game_with_dealer =
      game_with_active_player
      |> Map.put(:dealer_hand, dealer_hand)
      |> Map.put(:deck, deck)

    first_hand_id =
      game_with_dealer.players
      |> Map.get(game_with_dealer.active_player)
      |> next_active_hand_id()

    game_with_dealer
    |> Map.put(:active_hand, first_hand_id)
    |> Game.new!()
  end

  def payout(game, fun) when is_nil(game.active_player) do
    new_state =
      Enum.reduce(game.players, game, fn
        {player_id, player = %{valid_wager: true}}, game ->
          %{discard: discard_for_player, credits: new_credits, hands: face_up_hands} =
            Enum.reduce(player.hands, %{discard: [], credits: 0, hands: player.hands}, fn
              {hand_id, player_hand}, acc ->
                case Hand.beats?(player_hand, game.dealer_hand) do
                  true ->
                    acc
                    |> Map.update!(:credits, &(&1 + player_hand.wager * 2))
                    |> Map.update!(:discard, &(player_hand.cards ++ &1))

                  false ->
                    Map.update!(acc, :discard, &(player_hand.cards ++ &1))

                  nil ->
                    acc
                    |> Map.update!(:credits, &(&1 + player_hand.wager))
                    |> Map.update!(:discard, &(player_hand.cards ++ &1))
                end
                |> Map.update!(:hands, fn hands ->
                  face_up_hand =
                    update_in(player_hand.cards, fn cards ->
                      Enum.map(cards, &Map.put(&1, :face_down, false))
                    end)

                  Map.put(hands, hand_id, face_up_hand)
                end)
            end)

          game_with_player_updated =
            update_in(game.players[player_id], fn player ->
              player
              |> Map.update!(:credits, &(&1 + new_credits))
              |> Map.put(:hands, face_up_hands)
            end)

          update_in(game_with_player_updated.discard, &(discard_for_player ++ &1))

        {_player_id, _player}, game ->
          game
      end)
      |> Map.update!(:dealer_hand, fn dealer ->
        update_in(dealer.cards, fn cards ->
          Enum.map(cards, &Map.put(&1, :face_down, false))
        end)
      end)
      |> Map.update!(:discard, &(game.dealer_hand.cards ++ &1))
      |> Map.put(:state, :shuffling)

    fun.()
    new_state
  end

  def payout(game, _fun), do: game

  def clear_table(game, fun) when is_nil(game.active_player) do
    new_state =
      Enum.reduce(game.players, game, fn
        {player_id, player = %{valid_wager: true}}, game ->
          update_in(game.players[player_id], fn player ->
            player
            |> Map.put(:ready, false)
            |> Map.put(:hands, %{})
            |> Map.put(:insurance, nil)
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

  # if deck < 30% then, clear discard, reset deck
  # change it so that if dealer has 21 at start of game go to next game
  # blackjack doesnt immediately pay out and it should pay out 1.5x bet

  def play_dealer(game) when is_nil(game.active_player) do
    case game.dealer_hand.value do
      # dealer hits on soft 17
      [greater_value, _lesser_value] when greater_value <= 17 ->
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
    {deck, hand} =
      Hand.double_down(game.deck, game.players[game.active_player].hands[game.active_hand])

    game
    |> Map.put(:deck, deck)
    |> Map.from_struct()
    |> update_in([:players, game.active_player], fn player ->
      player
      |> Map.from_struct()
      |> Map.update!(:credits, & (&1 - hand.wager))
      |> update_in([:hands, game.active_hand], fn _ -> Map.put(hand, :wager, hand.wager*2) end)
      |> Player.new!()
    end)
    |> new!()
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

    game
    |> Map.put(:deck, deck)
    |> Map.from_struct()
    |> update_in([:players, game.active_player], fn player ->
      player
      |> Map.from_struct()
      |> update_in([:hands, game.active_hand], fn _ -> hand end)
      |> Player.new!()
    end)
    |> new!()
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

  def update_active_player(game) do
    hand = game.players[game.active_player].hands[game.active_hand]

    cond do
      not hand.complete ->
        game

      not is_nil(next_active_hand_id(game.players[game.active_player])) ->
        Map.put(
          game,
          :active_hand,
          next_active_hand_id(game.players[game.active_player])
        )

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

      true ->
        game
        |> Map.put(:active_player, nil)
        |> Map.put(:active_hand, nil)
    end
  end

  def show(game) when not is_nil(game.dealer_hand) do
    IO.inspect("Dealer:")

    Enum.each(game.dealer_hand.cards, fn
      %{value: value, face_down: false} ->
        IO.inspect(" - #{value}")

      _ ->
        IO.inspect("*****")
    end)

    Enum.each(game.players, fn
      {_player_id, %{name: name, hands: hands}} ->
        IO.inspect("#{name}:")

        Enum.each(hands, fn {_hand_id, %{cards: cards}} ->
          Enum.each(cards, fn
            %{value: value, face_down: false} ->
              IO.inspect(" - #{value}")

            _ ->
              IO.inspect("*****")
          end)
        end)
    end)
    game
  end

  def show(game), do: game

  def one_wager?(game),
    do: Enum.any?(game.players, &elem(&1, 1).valid_wager)
end
