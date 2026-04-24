defmodule MiniDiscord.ChatServer do
  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link(_opts) do
    pid = spawn_link(fn -> listen(4040) end)
    {:ok, pid}
  end

  def listen(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info("Serveur de chat démarré sur le port #{port}")
    accept_loop(socket)
  end

  defp accept_loop(socket) do
    {:ok, client_socket} = :gen_tcp.accept(socket)
    
    {:ok, pid} = MiniDiscord.ClientHandler.start_link(client_socket)
    :gen_tcp.controlling_process(client_socket, pid)
    
    accept_loop(socket)
  end
end