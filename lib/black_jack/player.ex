defmodule BlackJack.Player do
  defstruct [
    :name,
    :joined,
    :ready,
    :credits,
    :insurance,
    :hands,
    :id,
    :wager,
    :position,
  ]

  @defaults [
    credits: 500,
    wager: 0,
    hands: %{},
    joined: false,
    ready: false,
  ]

  def new!(params \\ []) do
    params =
      @defaults
      |> Keyword.merge(id: Ecto.UUID.generate())
      |> Keyword.merge(params)

    struct!(__MODULE__, Keyword.merge(@defaults, params))
  end
end
