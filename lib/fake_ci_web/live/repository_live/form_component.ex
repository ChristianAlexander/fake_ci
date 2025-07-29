defmodule FakeCiWeb.RepositoryLive.FormComponent do
  use FakeCiWeb, :live_component

  alias FakeCi.CI

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage repository records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="repository-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Repository</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{repository: repository} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(CI.change_repository(repository))
     end)}
  end

  @impl true
  def handle_event("validate", %{"repository" => repository_params}, socket) do
    changeset = CI.change_repository(socket.assigns.repository, repository_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"repository" => repository_params}, socket) do
    save_repository(socket, socket.assigns.action, repository_params)
  end

  defp save_repository(socket, :new, repository_params) do
    case CI.create_repository(repository_params) do
      {:ok, repository} ->
        notify_parent({:saved, repository})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
