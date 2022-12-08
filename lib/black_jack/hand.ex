defmodule BlackJack.Hand do
  defstruct [
    :cards,
    :id,
  ]

  @defaults [
    cards: [],
  ]

  def new!(params \\ []) do
    params =
      @defaults
      |> Keyword.merge(id: Ecto.UUID.generate())
      |> Keyword.merge(params)

    struct!(__MODULE__, Keyword.merge(@defaults, params))
  end
end
