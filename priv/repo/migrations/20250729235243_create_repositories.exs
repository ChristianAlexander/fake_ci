defmodule FakeCi.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories) do
      add :name, :string
      add :status, :string
      add :commit_sha, :string
      add :commit_message, :string
      add :branch, :string
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
