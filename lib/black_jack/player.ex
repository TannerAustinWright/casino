defmodule BlackJack.Player do
  defstruct [
    :name,
    :joined,
    :ready,
    :credits,
    :insurance,
    :hands,
    :id,
    :position,
    :valid_wager
  ]

  @defaults [
    credits: 500,
    hands: %{},
    joined: false,
    ready: false,
    valid_wager: false,
    insurance: false
  ]
  def new!(params \\ [])

  def new!(params) when is_map(params), do: new!(Map.to_list(params))

  def new!(params) do
    params =
      @defaults
      |> Keyword.merge(id: Ecto.UUID.generate())
      |> Keyword.merge(params)

    struct!(__MODULE__, Keyword.merge(@defaults, params))
  end

  def update_player_credits(player, wager) do
    Map.update!(player, :credits, &(&1 + wager))
  end

  def initial_hand(player) do
    player.hands
    |> Map.to_list()
    |> List.first()
    |> case do
      nil ->
        BlackJack.Hand.new!(wager: 0)

      {_hand_id, hand} ->
        hand
    end
  end
end
