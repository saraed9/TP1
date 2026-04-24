defmodule MiniDiscord.ClientHandler do
  use GenServer
  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    send_text(socket, "Bienvenue sur MiniDiscord!\nEntre ton pseudo : ")
    {:ok, %{socket: socket, pseudo: nil, salon: nil}}
  end

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    input = String.trim(data)

    cond do
      is_nil(state.pseudo) ->
        send_text(socket, "Salons disponibles : unSalon\nRejoins un salon : ")
        {:noreply, %{state | pseudo: input}}

      is_nil(state.salon) ->
        MiniDiscord.Salon.rejoindre(input, self())
        send_text(socket, "Tu es dans ##{input} — écris tes messages !\n")
        
        MiniDiscord.Salon.broadcast(input, "📢 #{state.pseudo} a rejoint ##{input}")
        {:noreply, %{state | salon: input}}

      true ->
        MiniDiscord.Salon.broadcast(state.salon, "[#{state.pseudo}]: #{input}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:message, msg}, state) do
    send_text(state.socket, msg <> "\n")
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Client #{state.pseudo} déconnecté.")
    {:stop, :normal, state}
  end

  defp send_text(socket, text) do
    :gen_tcp.send(socket, text)
  end
end