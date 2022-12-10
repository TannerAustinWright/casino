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
    :discard
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
        {_player_id, %{wager: 0}}, game ->
          game

        {player_id, _player}, game ->
          {hand, deck} = Hand.deal(game.deck)

          game
          |> update_in([:players, player_id], fn player ->
            Map.update!(player, :hands, &Map.put(&1, hand.id, hand))
          end)
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

  # dealer needs to play automatically
  # payout credits, clear wagers
  # update state taking_bets
  # discard dealer_hand
  # set active_player and active_hand to nil
  # update each players ready to false
  # set insurance to nil
  # discard players hands, reset player hands to %{}
  # if deck < 30% then, clear discard, reset deck
  # discard hands from player and dealer, reset player and dealer hands
  # get to game state waiting

  def play_dealer(game) do
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


  def hit_dealer(game) do
    {new_deck, new_dealer_hand} = Hand.hit(game.deck, game.dealer_hand)

    updated_game =
      game
      |> Map.put(:deck, new_deck)
      |> Map.put(:dealer_hand, new_dealer_hand)
      |> play_dealer()
  end

  def hit_player(game) do
    {deck, hand} = Hand.hit(game.deck, game.players[game.active_player].hands[game.active_hand])

    updated_game =
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

    cond do
      not hand.complete ->
        updated_game

      not is_nil(next_active_hand_id(game.players[game.active_player])) ->
        Map.put(updated_game, :active_hand, next_active_hand_id(game.players[game.active_player]))

      not is_nil(next_active_player_id(game.players)) ->
        updated_game
        |> Map.put(:active_player, next_active_player_id(game.players))
        |> Map.put(:active_hand, next_active_hand_id(game.players[game.active_player]))

      true ->
        updated_game
        |> Map.put(:active_player, nil)
        |> Map.put(:active_hand, nil)
    end
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
end
