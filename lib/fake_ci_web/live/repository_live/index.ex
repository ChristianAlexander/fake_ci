defmodule FakeCiWeb.RepositoryLive.Index do
  use FakeCiWeb, :live_view

  alias FakeCi.CI
  alias FakeCi.CI.Repository

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: CI.subscribe()
    {:ok, assign(socket, :repositories, CI.list_repositories())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Repository")
    |> assign(:repository, CI.get_repository!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Repository")
    |> assign(:repository, %Repository{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Repositories")
    |> assign(:repository, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    repository = CI.get_repository!(id)
    {:ok, _} = CI.delete_repository(repository)

    updated_repositories = Enum.reject(socket.assigns.repositories, &(&1.id == repository.id))
    {:noreply, assign(socket, :repositories, updated_repositories)}
  end

  @impl true
  def handle_info({:repository_created, repository}, socket) do
    updated_repositories = socket.assigns.repositories ++ [repository]
    {:noreply, assign(socket, :repositories, updated_repositories)}
  end

  @impl true
  def handle_info({:repository_updated, repository}, socket) do
    updated_repositories =
      Enum.map(socket.assigns.repositories, fn repo ->
        if repo.id == repository.id, do: repository, else: repo
      end)

    {:noreply, assign(socket, :repositories, updated_repositories)}
  end

  @impl true
  def handle_info({:repository_deleted, repository}, socket) do
    updated_repositories = Enum.reject(socket.assigns.repositories, &(&1.id == repository.id))
    {:noreply, assign(socket, :repositories, updated_repositories)}
  end

  @impl true
  def handle_info({FakeCiWeb.RepositoryLive.FormComponent, {:saved, _repository}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Repository created successfully")
     |> push_patch(to: ~p"/")}
  end
end
