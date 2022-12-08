defmodule BlackJack.Game do
@moduledoc """
states:
  idle  -   no players are in the server
  taking_bets   -   players are in the server, timeout has been set to start game
"""
  defstruct [
    :state,
    :minimum_wager,
    :dealer_hand,
    :active_player,
    :active_hand,
    :players
  ]

  @defaults [
    state: :idle,
    minimum_wager: 20,
    dealer_hand: [],
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
        player

      other ->
        other
    end)
    |> new!()
  end
end
