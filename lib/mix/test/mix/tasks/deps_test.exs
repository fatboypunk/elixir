Code.require_file "../../../test_helper.exs", __FILE__

defmodule Mix.Tasks.DepsTest do
  use MixTest.Case

  defmodule DepsApp do
    def project do
      [
        deps: [
          { :ok, "0.1.0",         github: "elixir-lang/ok" },
          { :invalidvsn, "0.2.0", raw: "deps/invalidvsn" },
          { :invalidapp, "0.1.0", raw: "deps/invalidapp" },
          { :noappfile, "0.1.0",  raw: "deps/noappfile" },
          { :uncloned,            git: "https://github.com/elixir-lang/uncloned.git" }
        ]
      ]
    end
  end

  defmodule SuccessfulDepsApp do
    def project do
      [
        deps: [
          { :ok, "0.1.0", raw: "deps/ok" }
        ]
      ]
    end
  end

  defmodule OutOfDateDepsApp do
    def project do
      [
        deps: [
          { :ok,       "0.1.0", git: "https://github.com/elixir-lang/ok.git" },
          { :uncloned, "0.1.0", git: "https://github.com/elixir-lang/uncloned.git" }
        ]
      ]
    end
  end

  defmodule ReqDepsApp do
    def project do
      [
        deps: [
          { :ok, %r"^0\.{1,2}",    raw: "deps/ok" },
          { :invalidvsn, %r"^2.0", raw: "deps/invalidvsn" },
          { :noappfile,            raw: "deps/noappfile" }
        ]
      ]
    end
  end

  test "prints list of dependencies and their status" do
    Mix.Project.push DepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.run []

      assert_received { :mix_shell, :info, ["* ok [git: \"https://github.com/elixir-lang/ok.git\"]"] }
      assert_received { :mix_shell, :info, ["  locked at abcdef"] }
      assert_received { :mix_shell, :info, ["  lock mismatch: the dependency is out of date"] }
      assert_received { :mix_shell, :info, ["* invalidvsn [raw: \"deps/invalidvsn\"]"] }
      assert_received { :mix_shell, :info, ["  the dependency does not match the specified version, got 0.1.0"] }
      assert_received { :mix_shell, :info, ["* invalidapp [raw: \"deps/invalidapp\"]"] }
      assert_received { :mix_shell, :info, ["  the app file at deps/invalidapp/ebin/invalidapp.app is invalid"] }
      assert_received { :mix_shell, :info, ["* noappfile [raw: \"deps/noappfile\"]"] }
      assert_received { :mix_shell, :info, ["  could not find app file at deps/noappfile/ebin/noappfile.app"] }
      assert_received { :mix_shell, :info, ["* uncloned [git: \"https://github.com/elixir-lang/uncloned.git\"]"] }
      assert_received { :mix_shell, :info, ["  the dependency is not available, run `mix deps.get`"] }
    end
  after
    Mix.Project.pop
  end

  test "prints list of dependencies and their status including req matches" do
    Mix.Project.push ReqDepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.run []

      assert_received { :mix_shell, :info, ["* ok (0.1.0) [raw: \"deps/ok\"]"] }
      assert_received { :mix_shell, :info, ["  ok"] }
      assert_received { :mix_shell, :info, ["* invalidvsn [raw: \"deps/invalidvsn\"]"] }
      assert_received { :mix_shell, :info, ["  the dependency does not match the specified version, got 0.1.0"] }
      assert_received { :mix_shell, :info, ["* noappfile [raw: \"deps/noappfile\"]"] }
      refute_received { :mix_shell, :info, ["  could not find app file at deps/noappfile/ebin/noappfile.app"] }
    end
  after
    Mix.Project.pop
  end

  test "check list of dependencies and their status with success" do
    Mix.Project.push SuccessfulDepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.Check.run []
    end
  after
    Mix.Project.pop
  end

  test "check list of dependencies and their status on the first run" do
    Mix.Project.push OutOfDateDepsApp

    in_fixture "deps_status", fn ->
      assert_raise Mix.OutOfDateDepsError, "Some dependencies are out of date, please run `mix deps.get` to proceed", fn ->
        Mix.Tasks.Deps.Check.run []
      end

      assert_received { :mix_shell, :error, ["* uncloned [git: \"https://github.com/elixir-lang/uncloned.git\"]"] }
    end
  after
    Mix.Project.pop
  end

  test "check list of dependencies and their status on failure" do
    Mix.Project.push DepsApp

    in_fixture "deps_status", fn ->
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Deps.Check.run []
      end

      assert_received { :mix_shell, :error, ["* ok [git: \"https://github.com/elixir-lang/ok.git\"]"] }
      assert_received { :mix_shell, :error, ["  lock mismatch: the dependency is out of date"] }
      assert_received { :mix_shell, :error, ["* invalidvsn [raw: \"deps/invalidvsn\"]"] }
      assert_received { :mix_shell, :error, ["  the dependency does not match the specified version, got 0.1.0"] }
      assert_received { :mix_shell, :error, ["* invalidapp [raw: \"deps/invalidapp\"]"] }
      assert_received { :mix_shell, :error, ["  the app file at deps/invalidapp/ebin/invalidapp.app is invalid"] }
      assert_received { :mix_shell, :error, ["* noappfile [raw: \"deps/noappfile\"]"] }
      assert_received { :mix_shell, :error, ["  could not find app file at deps/noappfile/ebin/noappfile.app"] }
      assert_received { :mix_shell, :error, ["* uncloned [git: \"https://github.com/elixir-lang/uncloned.git\"]"] }
      assert_received { :mix_shell, :error, ["  the dependency is not available, run `mix deps.get`"] }
    end
  after
    Mix.Project.pop
  end

  test "unlocks all deps" do
    in_fixture "no_mixfile", fn ->
      Mix.Deps.Lock.write [git_repo: "abcdef"]
      assert Mix.Deps.Lock.read == [git_repo: "abcdef"]
      Mix.Tasks.Deps.Unlock.run []
      assert Mix.Deps.Lock.read == []
    end
  end

  test "unlocks specific deps" do
    in_fixture "no_mixfile", fn ->
      Mix.Deps.Lock.write [git_repo: "abcdef", another: "hash"]
      Mix.Tasks.Deps.Unlock.run ["git_repo", "unknown"]
      assert Mix.Deps.Lock.read == [another: "hash"]
    end
  end

  ## Nested dependencies

  defmodule UnmetNestedDepsApp do
    def project do
      [
        app: :raw_sample,
        version: "0.1.0",
        deps: [
          { :deps_repo, "0.1.0", raw: "custom/deps_repo" }
        ]
      ]
    end
  end

  defmodule NestedDepsApp do
    def project do
      [
        app: :raw_sample,
        version: "0.1.0",
        deps: [
          { :git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo") },
          { :deps_repo, "0.1.0", raw: "custom/deps_repo" }
        ]
      ]
    end
  end

  test "fails on unmet nested dependencies" do
    Mix.Project.push UnmetNestedDepsApp

    in_fixture "deps_status", fn ->
      assert_raise Mix.OutOfDateDepsError, fn ->
        Mix.Tasks.Deps.Update.run []
      end

      assert_received { :mix_shell, :info, ["* Updating deps_repo [raw: \"custom/deps_repo\"]"] }
    end
  after
    purge [DepsRepo, DepsRepo.Mix]
    Mix.Project.pop
  end

  test "works with nested dependencies" do
    Mix.Project.push NestedDepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.Get.run ["git_repo"]
      message = "* Getting git_repo [git: #{inspect fixture_path("git_repo")}]"
      assert_received { :mix_shell, :info, [^message] }
      assert_received { :mix_shell, :info, ["Generated git_repo.app"] }

      Mix.Tasks.Deps.Update.run []
      assert_received { :mix_shell, :info, ["* Updating deps_repo [raw: \"custom/deps_repo\"]"] }
    end
  after
    purge [GitRepo, GitRepo.Mix, DepsRepo, DepsRepo.Mix]
    Mix.Project.pop
  end
end