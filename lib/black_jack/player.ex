defmodule BlackJack.Player do
  defstruct [
    :name,
    :credits,
    :insurance,
    :hands,
    :id
  ]

  @defaults [
    credits: 500,
    hands: %{}
  ]

  def new!(params \\ []) do
    params =
      @defaults
      |> Keyword.merge(id: Ecto.UUID.generate())
      |> Keyword.merge(params)

    struct!(__MODULE__, Keyword.merge(@defaults, params))
  end
end
