defmodule Casino.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # Casino.Repo,
      # Start the Telemetry supervisor
      CasinoWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Casino.PubSub},
      # Start the Endpoint (http/https)
      CasinoWeb.Endpoint,
      # Start a worker by calling: Casino.Worker.start_link(arg)
      # {Casino.Worker, arg}
      {
        Casino.Server,
        [name: Casino.Server]
      },
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Casino.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CasinoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
