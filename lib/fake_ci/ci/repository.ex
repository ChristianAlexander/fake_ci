defmodule FakeCi.CI.Repository do
  use Ecto.Schema
  import Ecto.Changeset

  schema "repositories" do
    field :name, :string
    field :status, Ecto.Enum, values: [:pending, :running, :success, :failure, :cancelled]
    field :started_at, :utc_datetime
    field :branch, :string
    field :commit_sha, :string
    field :commit_message, :string
    field :finished_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [
      :name,
      :status,
      :commit_sha,
      :commit_message,
      :branch,
      :started_at,
      :finished_at
    ])
    |> validate_required([:name])
  end
end
