defmodule FakeCi.CITest do
  use FakeCi.DataCase

  alias FakeCi.CI

  describe "repositories" do
    alias FakeCi.CI.Repository

    import FakeCi.CIFixtures

    @invalid_attrs %{
      name: nil,
      status: nil,
      started_at: nil,
      branch: nil,
      commit_sha: nil,
      commit_message: nil,
      finished_at: nil
    }

    test "list_repositories/0 returns all repositories" do
      repository = repository_fixture()
      assert CI.list_repositories() == [repository]
    end

    test "get_repository!/1 returns the repository with given id" do
      repository = repository_fixture()
      assert CI.get_repository!(repository.id) == repository
    end

    test "create_repository/1 with valid data creates a repository" do
      valid_attrs = %{
        name: "some name",
        status: "cancelled",
        started_at: ~U[2025-07-28 23:52:00Z],
        branch: "some branch",
        commit_sha: "some commit_sha",
        commit_message: "some commit_message",
        finished_at: ~U[2025-07-28 23:52:00Z]
      }

      assert {:ok, %Repository{} = repository} = CI.create_repository(valid_attrs)
      assert repository.name == "some name"
      assert repository.status == :cancelled
      assert repository.started_at == ~U[2025-07-28 23:52:00Z]
      assert repository.branch == "some branch"
      assert repository.commit_sha == "some commit_sha"
      assert repository.commit_message == "some commit_message"
      assert repository.finished_at == ~U[2025-07-28 23:52:00Z]
    end

    test "create_repository/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = CI.create_repository(@invalid_attrs)
    end

    test "update_repository/2 with valid data updates the repository" do
      repository = repository_fixture()

      update_attrs = %{
        name: "some updated name",
        status: :cancelled,
        started_at: ~U[2025-07-29 23:52:00Z],
        branch: "some updated branch",
        commit_sha: "some updated commit_sha",
        commit_message: "some updated commit_message",
        finished_at: ~U[2025-07-29 23:52:00Z]
      }

      assert {:ok, %Repository{} = repository} = CI.update_repository(repository, update_attrs)
      assert repository.name == "some updated name"
      assert repository.status == :cancelled
      assert repository.started_at == ~U[2025-07-29 23:52:00Z]
      assert repository.branch == "some updated branch"
      assert repository.commit_sha == "some updated commit_sha"
      assert repository.commit_message == "some updated commit_message"
      assert repository.finished_at == ~U[2025-07-29 23:52:00Z]
    end

    test "update_repository/2 with invalid data returns error changeset" do
      repository = repository_fixture()
      assert {:error, %Ecto.Changeset{}} = CI.update_repository(repository, @invalid_attrs)
      assert repository == CI.get_repository!(repository.id)
    end

    test "delete_repository/1 deletes the repository" do
      repository = repository_fixture()
      assert {:ok, %Repository{}} = CI.delete_repository(repository)
      assert_raise Ecto.NoResultsError, fn -> CI.get_repository!(repository.id) end
    end

    test "change_repository/1 returns a repository changeset" do
      repository = repository_fixture()
      assert %Ecto.Changeset{} = CI.change_repository(repository)
    end
  end
end
