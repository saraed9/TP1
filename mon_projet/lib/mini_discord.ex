defmodule MiniDiscord.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, [keys: :unique, name: MiniDiscord.Registry]},
      {DynamicSupervisor, strategy: :one_for_one, name: MiniDiscord.SalonSupervisor},
      {MiniDiscord.ChatServer,[]}
    ]

    opts = [strategy: :one_for_one, name: MiniDiscord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end