defmodule BlackJack.Hand do
  alias BlackJack.{
    Deck,
    Card
  }

  defstruct [
    :cards,
    :id,
    :value,
    :complete
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
end
