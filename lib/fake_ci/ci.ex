defmodule FakeCi.CI do
  @moduledoc """
  The CI context.
  """

  import Ecto.Query, warn: false
  alias FakeCi.Repo

  alias FakeCi.CI.Repository

  @topic "repositories"

  @doc """
  Returns the list of repositories.

  ## Examples

      iex> list_repositories()
      [%Repository{}, ...]

  """
  def list_repositories do
    Repository
    |> order_by([r], r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single repository.

  Raises `Ecto.NoResultsError` if the Repository does not exist.

  ## Examples

      iex> get_repository!(123)
      %Repository{}

      iex> get_repository!(456)
      ** (Ecto.NoResultsError)

  """
  def get_repository!(id), do: Repo.get!(Repository, id)

  @doc """
  Creates a repository.

  ## Examples

      iex> create_repository(%{field: value})
      {:ok, %Repository{}}

      iex> create_repository(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_repository(attrs \\ %{}) do
    case %Repository{}
         |> Repository.changeset(attrs)
         |> Repo.insert() do
      {:ok, repository} = result ->
        broadcast({:repository_created, repository})
        result

      error ->
        error
    end
  end

  @doc """
  Updates a repository.

  ## Examples

      iex> update_repository(repository, %{field: new_value})
      {:ok, %Repository{}}

      iex> update_repository(repository, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_repository(%Repository{} = repository, attrs) do
    case repository
         |> Repository.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_repository} = result ->
        broadcast({:repository_updated, updated_repository})
        result

      error ->
        error
    end
  end

  @doc """
  Deletes a repository.

  ## Examples

      iex> delete_repository(repository)
      {:ok, %Repository{}}

      iex> delete_repository(repository)
      {:error, %Ecto.Changeset{}}

  """
  def delete_repository(%Repository{} = repository) do
    case Repo.delete(repository) do
      {:ok, deleted_repository} = result ->
        broadcast({:repository_deleted, deleted_repository})
        result

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking repository changes.

  ## Examples

      iex> change_repository(repository)
      %Ecto.Changeset{data: %Repository{}}

  """
  def change_repository(%Repository{} = repository, attrs \\ %{}) do
    Repository.changeset(repository, attrs)
  end

  @doc """
  Subscribes to repository events.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(FakeCi.PubSub, @topic)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(FakeCi.PubSub, @topic, message)
  end
end
