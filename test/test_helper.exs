ExUnit.start

Mix.Task.run "ecto.create", ~w(-r MultiNode.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r MultiNode.Repo --quiet)
Ecto.Adapters.SQL.begin_test_transaction(MultiNode.Repo)

