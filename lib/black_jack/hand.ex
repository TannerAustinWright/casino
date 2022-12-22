defmodule BlackJack.Hand do
  alias BlackJack.{
    Deck,
    Card
  }

  @derive Jason.Encoder
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

    __MODULE__
    |> struct!(Keyword.merge(@defaults, params_with_hand_value))
    |> complete()
  end

  def complete(busted_hand = %{value: []}), do: Map.put(busted_hand, :complete, true)

  def complete(max_hand = %{value: [21 | _other]}), do: Map.put(max_hand, :complete, true)

  def complete(hand), do: hand

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

  def beats?(%{value: [player_value | _player_rest]}, %{
        cards: dealer_cards,
        value: [dealer_value | _dealer_rest]
      }) do
    cond do
      # dealer has blackjack everyone looses
      length(dealer_cards) === 2 and dealer_value === 21 -> false
      # dealer beats player
      dealer_value > player_value -> false
      # player beats dealer
      dealer_value < player_value -> true
      # push
      dealer_value === player_value -> nil
    end
  end

  # function execute first
  def beats?(%{value: []}, %{value: _other}) do
    false
  end

  # function execute second
  def beats?(%{value: _other}, %{value: []}) do
    true
  end

  def can_split?(%{cards: [%{value: value1}, %{value: value2}]}) when value1 === value2, do: true
  def can_split?(_hand), do: false

  def bust?(%{value: []}), do: true

  def bust?(_hand), do: false

  def black_jack?(%{value: [21 | _rest], cards: cards}) when length(cards) === 2, do: true
  def black_jack?(_hand), do: false

  def hit(deck, hand) do
    {card, new_deck} = Deck.draw(deck)

    new_hand =
      hand
      |> Map.update!(:cards, &[card | &1])
      |> Map.update!(:value, &Card.add(&1, card))
      |> complete()

    {new_deck, new_hand}
  end

  def max_value(%{value: []}), do: "bust"
  def max_value(%{value: [max_value | _rest]}), do: max_value

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
