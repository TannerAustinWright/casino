defmodule BlackJack.Deck do
  alias BlackJack.Card

  @deck Enum.flat_map(Card.suits(), fn suit ->
          Enum.map(Card.values(), fn value -> Card.new!(value: value, suit: suit) end)
        end)

  def new(number_of_decks),
    do: Enum.shuffle(Enum.flat_map(1..number_of_decks, fn _num -> @deck end))

  def draw(deck), do: List.pop_at(deck, Enum.random(0..(length(deck) - 1)))
end
