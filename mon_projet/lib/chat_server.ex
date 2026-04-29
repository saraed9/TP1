defmodule MiniDiscord.ChatServer do
  use GenServer
  require Logger
  @doc """
  Le chat server est un donc un serveur qui écoute des demandes de connections via tcp.
  A la reception d'une demande de connection, un processus de gestion de message est créé pour le nouveau client
  """

  @port 4040

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc """
  initialisation avec comme état un tuple vide
  - demande l'ecoute sur le port defini
  Returns `{:ok, {listen_socket,  #Port<0.3>}}` (par exemple), le nouvel etat
  ## Parameters
    - state: etat initial (vide)
  """
  def init(state) do
    {:ok, listen_socket} = :gen_tcp.listen(@port, [
      :binary, #chaines de caracteres
      packet: :line, #lire ligne / ligne
      active: false, # lire seulement par action receive
      reuseaddr: true # si le serveur redemarre, il reutilise la meme adresse (pour garantir la continuite des envois/receptions de messages)
    ])
    Logger.info("[^!^] Serveur démarré sur le port #{@port}")
    send(self(), :accept)
    {:ok, Map.put(state, :listen_socket, listen_socket)}
  end

  @doc """
  se lance a la reception d'un message
  - demande l'ecoute sur le port defini
  Returns `{:noreply, state}` avec state inchangé ({listen_socket,  #Port<0.3>} par exemple)
  ## Parameters
    - state: de type {listen_socket,  #Port<0.3>} dont on recupere le port  (dans ls)
  """
  def handle_info(:accept, %{listen_socket: ls} = state) do
    {:ok, client_socket} = :gen_tcp.accept(ls)
    Task.Supervisor.start_child(
      MiniDiscord.TaskSupervisor,
      fn -> MiniDiscord.ClientHandler.start(client_socket) end
    )
    send(self(), :accept)
    {:noreply, state}
  end
end
