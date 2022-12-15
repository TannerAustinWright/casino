defmodule BlackJack.Hand do
  alias BlackJack.{
    Deck,
    Card
  }

  defstruct [
    :cards,
    :id,
    :value,
    :complete,
    :wager
  ]

  @defaults [
    cards: [],
    value: [],
    complete: false
  ]

  def new!(params \\ []) do
    params =
      @defaults
      |> Keyword.merge(id: Ecto.UUID.generate())
      |> Keyword.merge(params)

    hand_value =
      Keyword.get(params, :cards)
      |> case do
        [card1, card2] ->
          Card.add(card1, card2)

        [] ->
          [0]
      end

    params_with_hand_value = Keyword.merge(params, value: hand_value)

    struct!(__MODULE__, Keyword.merge(@defaults, params_with_hand_value))
  end


  def deal(deck, dealer_or_player \\ :player)

  def deal(deck, :player) do
    {first_card, after_one_pop} = Deck.draw(deck)
    {second_card, new_deck} = Deck.draw(after_one_pop)

    {new!(cards: [first_card, second_card]), new_deck}
  end

  def deal(deck, :dealer) do
    {first_card, after_one_pop} = Deck.draw(deck)
    {second_card, new_deck} = Deck.draw(after_one_pop)
    first_card_face_down = Map.put(first_card, :face_down, true)

    {new!(cards: [first_card_face_down, second_card]), new_deck}
  end

  def beats?(%{value: [player_value | _player_rest]}, %{value: [dealer_value | _dealer_rest]}) do
    cond do
      dealer_value > player_value -> false
      dealer_value < player_value -> true
      dealer_value === player_value -> nil
    end
  end

  def beats?(%{value: []}, %{value: _other}) do # function execute first
    false
  end

  def beats?(%{value: _other}, %{value: []}) do # function execute second
    true
  end

  def bust?(%{value: []}), do: true

  def bust?(_hand), do: false

  def hit(deck, hand) do
    {card, new_deck} = Deck.draw(deck)

    new_hand =
      hand
      |> Map.update!(:cards, &[card | &1])
      |> Map.update!(:value, &Card.add(&1, card))
      |> case do
        busted_hand = %{value: []} ->
          Map.put(busted_hand, :complete, true)
        max_hand = %{value: [21 | _other]} ->
          Map.put(max_hand, :complete, true)
        other_hand ->
          other_hand
      end

    {new_deck, new_hand}
  end

  def double_down(deck, hand) do
    {card, new_deck} = Deck.draw(deck)

    face_down_card = Map.put(card, :face_down, true)

    new_hand =
      hand
      |> Map.update!(:cards, &[face_down_card | &1])
      |> Map.update!(:value, &Card.add(&1, face_down_card))
      |> Map.put(:complete, true)

    {new_deck, new_hand}
  end
end
