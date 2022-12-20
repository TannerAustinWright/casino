defmodule BlackJack.Deck do
  require Logger
  alias BlackJack.Card

  @deck Enum.flat_map(Card.suits(), fn suit ->
          Enum.map(Card.values(), fn value -> Card.new!(value: value, suit: suit) end)
        end)

  def new(number_of_decks),
    do: Enum.shuffle(Enum.flat_map(1..number_of_decks, fn _num -> @deck end))

  def draw([top_card | []]) do
    Logger.warn("Drew last card in the deck")
    {top_card, []}
  end

  def draw([top_card | rest_of_deck]), do: {top_card, rest_of_deck}
end
