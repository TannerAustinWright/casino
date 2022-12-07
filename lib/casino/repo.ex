defmodule Casino.Repo do
  use Ecto.Repo,
    otp_app: :casino,
    adapter: Ecto.Adapters.Postgres
end
