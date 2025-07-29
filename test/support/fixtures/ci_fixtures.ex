defmodule FakeCi.CIFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FakeCi.CI` context.
  """

  @doc """
  Generate a repository.
  """
  def repository_fixture(attrs \\ %{}) do
    {:ok, repository} =
      attrs
      |> Enum.into(%{
        branch: "some branch",
        commit_message: "some commit_message",
        commit_sha: "some commit_sha",
        finished_at: ~U[2025-07-28 23:52:00Z],
        name: "some name",
        started_at: ~U[2025-07-28 23:52:00Z],
        status: :pending
      })
      |> FakeCi.CI.create_repository()

    repository
  end
end
