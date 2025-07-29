defmodule FakeCi.Repo do
  use Ecto.Repo,
    otp_app: :fake_ci,
    adapter: Ecto.Adapters.Postgres
end
