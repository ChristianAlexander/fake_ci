defmodule FakeCi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    base_children = [
      FakeCiWeb.Telemetry,
      FakeCi.Repo,
      {DNSCluster, query: Application.get_env(:fake_ci, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FakeCi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FakeCi.Finch}
    ]

    activity_generator_children = [
      # Start the ActivityGenerator registry
      {Registry, keys: :unique, name: FakeCi.ActivityGeneratorRegistry},
      # Start the ActivityGenerator dynamic supervisor
      {DynamicSupervisor, name: FakeCi.CI.ActivityGeneratorSupervisor, strategy: :one_for_one},
      # Start the ActivityGenerator fanout manager
      {FakeCi.CI.ActivityGeneratorFanout, []}
    ]

    endpoint_children = [
      # Start a worker by calling: FakeCi.Worker.start_link(arg)
      # {FakeCi.Worker, arg},
      # Start to serve requests, typically the last entry
      FakeCiWeb.Endpoint
    ]

    children =
      if Mix.env() == :test do
        base_children ++ endpoint_children
      else
        base_children ++ activity_generator_children ++ endpoint_children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FakeCi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FakeCiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
