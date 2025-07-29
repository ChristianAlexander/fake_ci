defmodule FakeCi.CI.ActivityGenerator do
  @moduledoc """
  A GenServer that simulates realistic CI activity including developer commits
  and CI pipeline state transitions.

  Each instance is responsible for one repository and will simulate:
  - Developer commits being pushed
  - CI pipeline state transitions (pending -> running -> success/failure/cancelled)
  - Realistic timing between activities
  - Appropriate timestamp updates
  """

  use GenServer
  require Logger

  alias FakeCi.CI
  alias FakeCi.CI.Repository

  # Activity type weights (higher = more likely)
  @activity_weights %{
    new_commit: 30,
    ci_transition: 70
  }

  # Timing configurations
  # 3 seconds
  @min_interval 3_000
  # 25 seconds
  @max_interval 15_000
  # 5 seconds for CI steps
  @ci_min_duration 5_000
  # 45 seconds for CI steps
  @ci_max_duration 45_000

  defstruct [:repo_id, :timer_ref, :current_activity]

  ## Client API

  @doc """
  Starts an ActivityGenerator for the given repository ID.
  """
  def start_link(repo_id) when is_integer(repo_id) do
    GenServer.start_link(__MODULE__, repo_id, name: via_tuple(repo_id))
  end

  @doc """
  Stops the ActivityGenerator for the given repository ID.
  """
  def stop(repo_id) do
    case Registry.lookup(FakeCi.ActivityGeneratorRegistry, repo_id) do
      [{pid, _}] -> GenServer.stop(pid)
      [] -> :ok
    end
  end

  @doc """
  Forces an immediate activity generation for the given repository ID.
  """
  def generate_activity_now(repo_id) do
    case Registry.lookup(FakeCi.ActivityGeneratorRegistry, repo_id) do
      [{pid, _}] -> GenServer.cast(pid, :generate_activity)
      [] -> {:error, :not_found}
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(repo_id) do
    Logger.info("Starting ActivityGenerator for repository #{repo_id}")

    # Verify the repository exists
    try do
      case CI.get_repository!(repo_id) do
        %Repository{} = _repo ->
          state = %__MODULE__{
            repo_id: repo_id,
            current_activity: :idle
          }

          new_state = schedule_next_activity(state)
          {:ok, new_state}

        _ ->
          {:stop, {:error, :repository_not_found}}
      end
    rescue
      Ecto.NoResultsError ->
        Logger.error("Repository #{repo_id} not found")
        {:stop, {:error, :repository_not_found}}
    end
  end

  @impl true
  def handle_info(:generate_activity, %__MODULE__{} = state) do
    new_state = generate_activity(state)
    new_state = schedule_next_activity(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:generate_activity, %__MODULE__{} = state) do
    new_state = generate_activity(state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(reason, %__MODULE__{repo_id: repo_id, timer_ref: timer_ref}) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
    Logger.info("ActivityGenerator for repository #{repo_id} terminated: #{inspect(reason)}")
    :ok
  end

  ## Private Functions

  defp via_tuple(repo_id) do
    {:via, Registry, {FakeCi.ActivityGeneratorRegistry, repo_id}}
  end

  defp schedule_next_activity(%__MODULE__{timer_ref: old_timer_ref, repo_id: repo_id} = state) do
    if old_timer_ref, do: Process.cancel_timer(old_timer_ref)

    interval =
      case state.current_activity do
        :ci_running ->
          # CI activities happen faster
          Enum.random(@ci_min_duration..@ci_max_duration)

        :idle ->
          # Check if this is the initial state (status is nil)
          case CI.get_repository!(repo_id) do
            %Repository{status: nil} ->
              # Make first activity happen quickly (1-3 seconds)
              Enum.random(1_000..3_000)

            _ ->
              # Regular activity interval
              Enum.random(@min_interval..@max_interval)
          end

        _ ->
          # Regular activity interval
          Enum.random(@min_interval..@max_interval)
      end

    timer_ref = Process.send_after(self(), :generate_activity, interval)

    Logger.debug("Next activity for repository #{state.repo_id} scheduled in #{interval}ms")

    %{state | timer_ref: timer_ref}
  end

  defp generate_activity(%__MODULE__{repo_id: repo_id} = state) do
    try do
      # Allow the test process to checkout from the DB pool
      if Mix.env() == :test do
        Ecto.Adapters.SQL.Sandbox.allow(FakeCi.Repo, self(), self())
      end

      repo = CI.get_repository!(repo_id)
      activity_type = determine_activity_type(repo, state)

      case activity_type do
        :new_commit ->
          Logger.info("Generating new commit for repository #{repo_id}")
          generate_developer_commit(repo)
          %{state | current_activity: :pending_ci}

        :ci_transition ->
          Logger.info("Generating CI transition for repository #{repo_id}")
          new_activity = generate_ci_transition(repo)
          %{state | current_activity: new_activity}
      end
    rescue
      exception ->
        Logger.error("Error generating activity for repository #{repo_id}: #{inspect(exception)}")
        state
    end
  end

  defp determine_activity_type(repo, state) do
    case {repo.status, state.current_activity} do
      # If status is nil (initial state), always generate a commit first
      {nil, _} ->
        :new_commit

      # If CI is running, continue with CI transitions
      {:running, _} ->
        :ci_transition

      # If we just had a commit, start CI
      {_, :pending_ci} ->
        :ci_transition

      # If we're in a final state, generate new commit or transition
      {status, _} when status in [:success, :failure, :cancelled] ->
        if should_generate_new_commit?() do
          :new_commit
        else
          :ci_transition
        end

      # Default case - mostly new commits
      _ ->
        if should_generate_new_commit?() do
          :new_commit
        else
          :ci_transition
        end
    end
  end

  defp should_generate_new_commit? do
    total_weight = @activity_weights.new_commit + @activity_weights.ci_transition
    random_value = Enum.random(1..total_weight)
    random_value <= @activity_weights.new_commit
  end

  defp generate_developer_commit(repo) do
    commit_attrs = %{
      commit_sha: generate_random_sha(),
      commit_message: generate_random_commit_message(),
      branch: generate_random_branch(),
      status: :pending,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      finished_at: nil
    }

    case CI.update_repository(repo, commit_attrs) do
      {:ok, updated_repo} ->
        Logger.info("Developer pushed commit #{updated_repo.commit_sha} to repository #{repo.id}")

      {:error, changeset} ->
        Logger.error("Failed to update repository #{repo.id}: #{inspect(changeset.errors)}")
    end
  end

  defp generate_ci_transition(repo) do
    {new_status, new_activity} = determine_next_ci_state(repo.status)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ci_attrs =
      case new_status do
        :running ->
          %{
            status: :running,
            started_at: now,
            finished_at: nil
          }

        final_status when final_status in [:success, :failure, :cancelled] ->
          %{
            status: final_status,
            finished_at: now
          }

        _ ->
          %{status: new_status}
      end

    case CI.update_repository(repo, ci_attrs) do
      {:ok, updated_repo} ->
        Logger.info(
          "CI transitioned to #{new_status} for repository #{repo.id} (#{updated_repo.commit_sha})"
        )

      {:error, changeset} ->
        Logger.error("Failed to update repository #{repo.id}: #{inspect(changeset.errors)}")
    end

    new_activity
  end

  defp determine_next_ci_state(current_status) do
    case current_status do
      :pending ->
        {:running, :ci_running}

      :running ->
        # CI completes with weighted outcomes
        outcome =
          Enum.random([
            # 50% success
            :success,
            :success,
            :success,
            :success,
            :success,
            # 30% failure
            :failure,
            :failure,
            :failure,
            # 10% cancelled
            :cancelled
          ])

        {outcome, :idle}

      # If already in final state, small chance to restart with new commit
      final_status when final_status in [:success, :failure, :cancelled] ->
        # 20% chance
        if Enum.random(1..10) <= 2 do
          {:pending, :pending_ci}
        else
          {final_status, :idle}
        end

      _ ->
        {:pending, :idle}
    end
  end

  defp generate_random_sha do
    :crypto.strong_rand_bytes(20)
    |> Base.encode16(case: :lower)
  end

  defp generate_random_commit_message do
    commit_types = [
      {"feat", ["add", "implement", "create", "introduce"]},
      {"fix", ["resolve", "correct", "repair", "address"]},
      {"docs", ["update", "improve", "add", "fix"]},
      {"style", ["format", "cleanup", "polish", "refactor"]},
      {"refactor", ["restructure", "optimize", "simplify", "reorganize"]},
      {"test", ["add", "update", "improve", "fix"]},
      {"chore", ["update", "bump", "maintain", "configure"]}
    ]

    {commit_type, verbs} = Enum.random(commit_types)
    verb = Enum.random(verbs)

    feature_words = [
      "authentication",
      "validation",
      "logging",
      "caching",
      "routing",
      "database",
      "API",
      "interface",
      "component",
      "service",
      "utility",
      "configuration",
      "security",
      "performance",
      "monitoring",
      "testing",
      "documentation",
      "deployment",
      "integration",
      "migration",
      "backup"
    ]

    detail_words = [
      "system",
      "module",
      "handler",
      "middleware",
      "controller",
      "model",
      "view",
      "helper",
      "factory",
      "builder",
      "parser",
      "validator",
      "formatter",
      "processor",
      "manager",
      "client",
      "server",
      "worker"
    ]

    feature = Enum.random(feature_words)
    detail = Enum.random(detail_words)

    "#{commit_type}: #{verb} #{feature} #{detail}"
  end

  defp generate_random_branch do
    branch_types = [
      {"main", 20},
      {"develop", 15},
      {"feature", 40},
      {"hotfix", 15},
      {"release", 10}
    ]

    # Weighted random selection
    total_weight = Enum.sum(Enum.map(branch_types, fn {_, weight} -> weight end))
    random_value = Enum.random(1..total_weight)

    {branch_type, _} =
      Enum.reduce_while(branch_types, {nil, 0}, fn {type, weight}, {_, acc} ->
        new_acc = acc + weight

        if random_value <= new_acc do
          {:halt, {type, new_acc}}
        else
          {:cont, {type, new_acc}}
        end
      end)

    case branch_type do
      "main" ->
        "main"

      "develop" ->
        "develop"

      "feature" ->
        features = [
          "user-auth",
          "payment-flow",
          "admin-panel",
          "api-v2",
          "mobile-app",
          "dashboard",
          "notifications",
          "search",
          "analytics",
          "reporting"
        ]

        "feature/#{Enum.random(features)}"

      "hotfix" ->
        issues = ["security-patch", "critical-bug", "memory-leak", "data-corruption", "crash-fix"]
        "hotfix/#{Enum.random(issues)}"

      "release" ->
        version = "#{Enum.random(1..3)}.#{Enum.random(0..9)}.#{Enum.random(0..9)}"
        "release/v#{version}"
    end
  end
end
