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

  @deck_count 1

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
    :start_game_scheduled_message
  ]

  @defaults [
    next_position: 0,
    state: :idle,
    minimum_wager: 20,
    dealer_hand: [],
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

  def create_player(game, player) do
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

  def payout_clear_wagers(game) do
    Enum.each(game.players, fn
      {_player_id, player} ->
        Enum.each(player.hands, fn
          {_hand_id, player_hand} ->
            case Hand.beats?(player_hand, game.dealer_hand) do
              # Player.update_player_credits(2*)
              true -> nil
              # do nothing
              false -> nil
              # update player credits to += wager
              nil -> nil
            end
        end)
    end)

    # dealer_value = dealer value pattern match [nil] or [d_int] or [d_greatest_int, _d_lowest_int]
    # for each player in active players
    # for each hand in player
    # hand_value = pattern match [nil] or [int] or [g_int, _l_int]
    # case hand_value do
    # [nil] -> add hand_value credits to house_credits
    # [int] or [g_int, _l_int] ->
    # [p_int] = [int] or [p_int, _other] = [g_int, _l_int] depending on pattern match?
    # case dealer_value do
    # [nil] or [d_int] < [p_int] or [d_greatest_int] < [p_int] -> add 2*hand_value to player credits, subtract hand_value from house_credits
    # [d_int] == [p_int] or [d_greatest_int] == [p_int] -> add hand_value to player credits
    # [d_int] > [p_int] or [d_greatest_int] > [p_int] -> add hand_value to house_credits
  end

  # update players function:
  # payout credits, clear wagers
  # update each players ready to false
  # set insurance to nil
  # discard players hands, reset player hands to %{}

  # get to game state waiting
  # set active_player and active_hand to nil
  # discard dealer_hand
  # update state taking_bets
  # if deck < 30% then, clear discard, reset deck

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

  def print_cards(game) do
    IO.inspect("Dealer:")

    Enum.each(game.dealer_hand.cards, fn
      %{value: value, face_down: false} ->
        IO.inspect(" - #{value}")

      _ ->
        nil
    end)

    Enum.each(game.players, fn
      {_player_id, %{name: name, hands: hands}} ->
        IO.inspect("#{name}:")

        Enum.each(hands, fn {_hand_id, %{cards: cards}} ->
          Enum.each(cards, fn card -> IO.inspect(" - #{card.value}") end)
        end)
    end)
  end

  def one_wager?(game),
    do: Enum.any?(game.players, &elem(&1, 1).valid_wager)
end
