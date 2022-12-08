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

  def deal_two(deck) do
    {first_card, after_one_pop} = List.pop_at(deck, Enum.random(1..length(deck)))
    {second_card, new_deck} = List.pop_at(after_one_pop, Enum.random(1..length(after_one_pop)))

    {new!(cards: [first_card, second_card]), new_deck}
  end
end
