defmodule BlackJack.Card do
  defstruct [
    :suit,
    :value,
    :face_down
  ]

  @defaults [
    face_down: false
  ]

  def new!(params \\ []) do
    struct!(__MODULE__,  Keyword.merge(@defaults, params))
  end

  def get_value(%{value: "ace"}), do: [1, 11]

  def get_value(card) do
    case Integer.parse(card.value) do
      {int_value, _string} ->
        [int_value]
      _other ->
        [10]
    end
  end

  def add(value, card) when is_list(value) do
    for x <- value, y <- get_value(card), reduce: [] do
      running_list ->
      sum = x + y
      if sum > 21, do: running_list, else: [sum | running_list]
    end
  end

  def add(card1, card2) do
    for x <- get_value(card1), y <- get_value(card2), reduce: [] do
      running_list ->
      sum = x + y
      if sum > 21, do: running_list, else: [sum | running_list]
    end
  end
end
