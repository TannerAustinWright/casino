defmodule BlackJack.Game do
  @moduledoc """
  states:
    idle  -   no players are in the server
    taking_bets   -   players are in the server, timeout has been set to start game
  """
  alias BlackJack.{
    Game,
    Deck,
    Hand
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
          {hand, deck} = Hand.deal_two(game.deck)

          game
          |> update_in([:players, player_id], fn player ->
            Map.update!(player, :hands, &Map.put(&1, hand.id, hand))
          end)
          |> Map.put(:deck, deck)
      end)
      |> Map.put(:state, :in_progress)
      |> Map.put(:active_player, elem(Enum.min_by(game.players, &elem(&1, 1).position), 0))
      |> IO.inspect(label: GameWithHands)

    {dealer_hand, deck} = Hand.deal_two(game_with_hands.deck, :dealer)

    game_with_dealer =
      game_with_hands
      |> Map.put(:dealer_hand, dealer_hand)
      |> Map.put(:deck, deck)

    first_hand_id =
      game_with_dealer.players[game_with_dealer.active_player].hands
      |> Map.keys()
      |> List.first()

    game_with_dealer
    |> Map.put(:active_hand, first_hand_id)
    |> Game.new!()
  end
end
