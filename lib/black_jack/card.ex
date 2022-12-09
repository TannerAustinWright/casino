defmodule BlackJack.Card do
  defstruct [
    :suit,
    :card,
    :face_down
  ]

  @defaults [
    face_down: false
  ]

  def new!(params \\ []) do
    struct!(__MODULE__,  Keyword.merge(@defaults, params))
  end
end
