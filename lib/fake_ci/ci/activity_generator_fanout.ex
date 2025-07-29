defmodule FakeCi.CI.ActivityGeneratorFanout do
  @moduledoc """
  A GenServer that manages ActivityGenerator processes via DynamicSupervisor.

  This module handles starting and stopping ActivityGenerator processes for repositories
  and provides a clean API for managing the entire system.
  """

  use GenServer
  require Logger

  alias FakeCi.CI
  alias FakeCi.CI.ActivityGenerator
  alias FakeCi.CI.ActivityGeneratorSupervisor

  ## Client API

  @doc """
  Starts the ActivityGeneratorFanout.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts an ActivityGenerator for the given repository ID.
  """
  def start_generator(repo_id) when is_integer(repo_id) do
    GenServer.call(__MODULE__, {:start_generator, repo_id})
  end

  @doc """
  Stops the ActivityGenerator for the given repository ID.
  """
  def stop_generator(repo_id) when is_integer(repo_id) do
    GenServer.call(__MODULE__, {:stop_generator, repo_id})
  end

  @doc """
  Lists all currently running ActivityGenerator processes.
  """
  def list_generators do
    GenServer.call(__MODULE__, :list_generators)
  end

  @doc """
  Starts ActivityGenerators for all repositories.
  """
  def start_all do
    GenServer.cast(__MODULE__, :start_all)
  end

  @doc """
  Stops all running ActivityGenerator processes.
  """
  def stop_all do
    GenServer.cast(__MODULE__, :stop_all)
  end

  @doc """
  Refreshes all generators based on current repositories.
  """
  def refresh_all do
    GenServer.cast(__MODULE__, :refresh_all)
  end

  @doc """
  Gets status information.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting ActivityGeneratorFanout")

    # Subscribe to repository events
    CI.subscribe()

    # Start generators for all repositories unless in test environment
    if Mix.env() != :test do
      send(self(), :start_all_generators)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:start_all_generators, state) do
    Logger.info("Auto-starting ActivityGenerators for all repositories")
    start_all_generators()
    {:noreply, state}
  end

  @impl true
  def handle_info({:repository_created, repository}, state) do
    Logger.info(
      "Repository created, starting ActivityGenerator for repository #{repository.id} (#{repository.name})"
    )

    case start_generator_impl(repository.id) do
      {:ok, _pid} ->
        Logger.info("Successfully started ActivityGenerator for new repository #{repository.id}")

      {:error, reason} ->
        Logger.error(
          "Failed to start ActivityGenerator for new repository #{repository.id}: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:repository_deleted, repository}, state) do
    Logger.info(
      "Repository deleted, stopping ActivityGenerator for repository #{repository.id} (#{repository.name})"
    )

    case stop_generator_impl(repository.id) do
      :ok ->
        Logger.info(
          "Successfully stopped ActivityGenerator for deleted repository #{repository.id}"
        )

      {:error, reason} ->
        Logger.error(
          "Failed to stop ActivityGenerator for deleted repository #{repository.id}: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:repository_updated, _repository}, state) do
    # No action needed for repository updates
    {:noreply, state}
  end

  @impl true
  def handle_call({:start_generator, repo_id}, _from, state) do
    result = start_generator_impl(repo_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:stop_generator, repo_id}, _from, state) do
    result = stop_generator_impl(repo_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_generators, _from, state) do
    result = list_generators_impl()
    {:reply, result, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    running_generators = list_generators_impl()
    count = DynamicSupervisor.count_children(ActivityGeneratorSupervisor)

    status = %{
      running_generators: running_generators,
      count: count,
      repositories_count: length(CI.list_repositories())
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:start_all, state) do
    start_all_generators()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop_all, state) do
    stop_all_generators()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:refresh_all, state) do
    refresh_all_generators()
    {:noreply, state}
  end

  ## Private Implementation

  defp start_generator_impl(repo_id) do
    child_spec = {ActivityGenerator, repo_id}

    case DynamicSupervisor.start_child(ActivityGeneratorSupervisor, child_spec) do
      {:ok, pid} ->
        Logger.info("Started ActivityGenerator for repository #{repo_id}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("ActivityGenerator for repository #{repo_id} already running")
        {:ok, pid}

      {:error, {:shutdown, {:error, :repository_not_found}}} ->
        Logger.error("Repository #{repo_id} not found")
        {:error, :repository_not_found}

      {:error, {:error, reason}} ->
        Logger.error(
          "Failed to start ActivityGenerator for repository #{repo_id}: #{inspect(reason)}"
        )

        {:error, reason}

      {:error, reason} = error ->
        Logger.error(
          "Failed to start ActivityGenerator for repository #{repo_id}: #{inspect(reason)}"
        )

        error
    end
  end

  defp stop_generator_impl(repo_id) do
    case Registry.lookup(FakeCi.ActivityGeneratorRegistry, repo_id) do
      [{pid, _}] ->
        case DynamicSupervisor.terminate_child(ActivityGeneratorSupervisor, pid) do
          :ok ->
            Logger.info("Stopped ActivityGenerator for repository #{repo_id}")
            :ok

          {:error, reason} = error ->
            Logger.error(
              "Failed to stop ActivityGenerator for repository #{repo_id}: #{inspect(reason)}"
            )

            error
        end

      [] ->
        Logger.info("ActivityGenerator for repository #{repo_id} not found")
        :ok
    end
  end

  defp list_generators_impl do
    DynamicSupervisor.which_children(ActivityGeneratorSupervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(FakeCi.ActivityGeneratorRegistry, pid) do
        [repo_id] -> {repo_id, pid}
        _ -> {nil, pid}
      end
    end)
    |> Enum.reject(fn {repo_id, _pid} -> is_nil(repo_id) end)
  end

  defp start_all_generators do
    repositories = CI.list_repositories()

    Enum.each(repositories, fn repo ->
      case start_generator_impl(repo.id) do
        {:ok, _pid} ->
          Logger.info(
            "Successfully started ActivityGenerator for repository #{repo.id} (#{repo.name})"
          )

        {:error, reason} ->
          Logger.error(
            "Failed to start ActivityGenerator for repository #{repo.id} (#{repo.name}): #{inspect(reason)}"
          )
      end
    end)

    Logger.info("Finished starting ActivityGenerators for #{length(repositories)} repositories")
  end

  defp stop_all_generators do
    list_generators_impl()
    |> Enum.each(fn {repo_id, _pid} ->
      stop_generator_impl(repo_id)
    end)
  end

  defp refresh_all_generators do
    Logger.info("Refreshing all ActivityGenerators")

    # Get current repositories
    current_repos = CI.list_repositories() |> MapSet.new(& &1.id)

    # Get running generators
    running_generators = list_generators_impl() |> MapSet.new(fn {repo_id, _pid} -> repo_id end)

    # Stop generators for repositories that no longer exist
    to_stop = MapSet.difference(running_generators, current_repos)

    Enum.each(to_stop, fn repo_id ->
      Logger.info("Stopping ActivityGenerator for deleted repository #{repo_id}")
      stop_generator_impl(repo_id)
    end)

    # Start generators for new repositories
    to_start = MapSet.difference(current_repos, running_generators)

    Enum.each(to_start, fn repo_id ->
      Logger.info("Starting ActivityGenerator for new repository #{repo_id}")
      start_generator_impl(repo_id)
    end)

    Logger.info(
      "Refresh complete. Stopped: #{MapSet.size(to_stop)}, Started: #{MapSet.size(to_start)}"
    )
  end
end
