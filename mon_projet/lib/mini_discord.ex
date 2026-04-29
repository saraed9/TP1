defmodule MiniDiscord do
  use Application

  def start(_type, _args) do
    # Pour l'unicite des pseudos (table ETS)
    :ets.new(:pseudos, [:named_table, :public, :set])


    children = [
      {Registry, keys: :unique, name: MiniDiscord.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: MiniDiscord.SalonSupervisor},
      MiniDiscord.ChatServer,
      {Task.Supervisor, name: MiniDiscord.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: MiniDiscord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end