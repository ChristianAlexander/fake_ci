defmodule FakeCiWeb.RepositoryLiveTest do
  use FakeCiWeb.ConnCase

  import Phoenix.LiveViewTest
  import FakeCi.CIFixtures

  @create_attrs %{
    name: "some name"
  }
  @invalid_attrs %{
    name: nil
  }

  defp create_repository(_) do
    repository = repository_fixture()
    %{repository: repository}
  end

  describe "Index" do
    setup [:create_repository]

    test "lists all repositories", %{conn: conn, repository: repository} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Listing Repositories"
      assert html =~ repository.name
    end

    test "saves new repository", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/")

      assert index_live |> element("a", "Add Repository") |> render_click() =~
               "Add Repository"

      assert_patch(index_live, ~p"/repositories/new")

      assert index_live
             |> form("#repository-form", repository: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#repository-form", repository: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/")

      html = render(index_live)
      assert html =~ "Repository created successfully"
      assert html =~ "some name"
    end

    test "deletes repository in listing", %{conn: conn, repository: repository} do
      {:ok, index_live, _html} = live(conn, ~p"/")

      assert index_live
             |> element("#delete-repository-#{repository.id}")
             |> render_click()

      refute has_element?(index_live, "#delete-repository-#{repository.id}")
    end
  end
end
