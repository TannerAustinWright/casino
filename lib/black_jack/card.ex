defmodule BlackJack.Card do
  defstruct [
    :suit,
    :card,
    :face_down
  ]

  def new!(params \\ []) do
    struct!(__MODULE__,  params)
  end
end
