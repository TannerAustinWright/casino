defmodule BlackJack.Deck do
  alias BlackJack.Card

  @suits [
    "spades",
    "diamonds",
    "clubs",
    "hearts"
  ]

  @cards [
    "ace",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "jack",
    "queen",
    "king"
  ]

  @deck Enum.flat_map(@suits, fn suit -> Enum.map(@cards, fn card -> Card.new!(card: card, suit: suit) end)end)

  def new(number_of_decks), do: Enum.flat_map(1..number_of_decks, fn _num -> @deck end)
end
