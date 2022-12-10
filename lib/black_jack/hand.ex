defmodule BlackJack.Hand do
  defstruct [
    :cards,
    :id
  ]

  @defaults [
    cards: []
  ]

  def new!(params \\ []) do
    params =
      @defaults
      |> Keyword.merge(id: Ecto.UUID.generate())
      |> Keyword.merge(params)

    struct!(__MODULE__, Keyword.merge(@defaults, params))
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

  def hit(hand, deck) do
    {card, new_deck} = Deck.draw(deck)

    Map.update!(hand, :cards, &[card | &1])


    # update total

    {new_deck, new_hand}
  end

  def total(hand), do: Enum.reduce(hand, &get_value/2)


end
