defmodule MiniDiscord.Salon do 
  use GenServer

  def start_link(nom_salon) do
    GenServer.start_link(__MODULE__, nom_salon, name: via(nom_salon))
  end

  def rejoindre(nom_salon, client_pid) do 
    GenServer.call(via(nom_salon), {:rejoindre, client_pid})
  end 

  def broadcast(nom_salon, message) do
    GenServer.cast(via(nom_salon), {:broadcast, message})
  end

  @impl true
  def init(nom_salon) do
    # On initialise l'état avec le nom du salon et une liste de clients vide
    {:ok, %{name: nom_salon, clients: []}}
  end

  @impl true
  def handle_call({:rejoindre, client_pid}, _from, state) do
    # On surveille le client pour savoir s'il se déconnecte
    Process.monitor(client_pid)
    # Q1) Pour être notifié par un message :DOWN si le client crash ou se déconnecte.
    # On ajoute le client à la liste existante dans le state
    nouveau_state = %{state | clients: [client_pid | state.clients]}
    
    # On répond :ok et on sauvegarde le nouveau state
    {:reply, :ok, nouveau_state}
  end 

  @impl true
  def handle_cast({:broadcast, message}, state) do 
    # hanya kan On envoie le message à chaque PID de la liste
    Enum.each(state.clients, fn pid -> 
      send(pid, {:message, message})
    end)
    
    {:noreply, state}
  end 

  @impl true
  #Q2) Pour nettoyer la liste des clients et éviter de garder des PIDs morts (fuite mémoire).
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # hnaya kan On retire le PID du client qui vient de se déconnecter
    nouveaux_clients = List.delete(state.clients, pid)
  
    # hnaya kan met à jour l'état du serveur
    {:noreply, %{state | clients: nouveaux_clients}}
  end
#Q3) Cast est asynchrone (non-bloquant) : on n'attend pas que tout le monde reçoive 
# Q3)le message pour libérer l'envoyeur. Call est synchrone (bloquant).
  defp via(nom_salon) do
    {:via, Registry, {MiniDiscord.Registry, nom_salon}}
  end
end