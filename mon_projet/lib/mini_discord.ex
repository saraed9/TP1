defmodule MiniDiscord do
  use Application

  def start(_type, _args) do
    # Creation d'une table ETS pour stocker les pseudos
    :ets.new(:pseudos, [:named_table, :public, :set])


    children = [
      {Registry, keys: :unique, name: MiniDiscord.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: MiniDiscord.SalonSupervisor},
      MiniDiscord.ChatServer,
      {Task.Supervisor, name: MiniDiscord.TaskSupervisor}
    ]
    # On utilise one_for_one car si le service crash seul lui est redemarre 
    opts = [strategy: :one_for_one, name: MiniDiscord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end