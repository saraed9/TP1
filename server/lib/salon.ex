defmodule MiniDiscord.Salon do
  use GenServer

  @doc """
  Demarrage du salon avec état complet :
  name, clients, historique, password (nil = pas de mot de passe)
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__,
      %{name: name, clients: [], historique: [], password: nil},
      name: via(name)
    )
  end

  # API publique
  def rejoindre(salon, pid, password \\ nil), do: GenServer.call(via(salon), {:rejoindre, pid, password})
  def quitter(salon, pid),                   do: GenServer.call(via(salon), {:quitter, pid})
  def broadcast(salon, msg),                 do: GenServer.cast(via(salon), {:broadcast, msg})
  def definir_password(salon, password),     do: GenServer.call(via(salon), {:password, password})

  def lister do
  #recupere tous les noms enregistres daans le registry
    Registry.select(MiniDiscord.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def init(state), do: {:ok, state}

  def handle_call({:rejoindre, pid, password}, _from, state) do
  acces = cond do
    state.password == nil and (password == nil or password == "") -> true  # pas de mdp défini, pas de mdp fourni → ok
    state.password == nil and password != "" ->                      # premier à entrer avec un mdp → il le définit
      :premier_avec_password
    password == nil or password == "" -> false                       # mdp requis mais rien fourni
    :crypto.hash(:sha256, password) == state.password -> true        # bon mdp
    true -> false                                                     # mauvais mdp
  end

  case acces do
    :premier_avec_password ->
      hash = :crypto.hash(:sha256, password)
      new_state = %{state | password: hash, clients: [pid | state.clients]}
      Process.monitor(pid)
      state.historique |> Enum.reverse() |> Enum.each(fn msg -> send(pid, {:message, msg}) end)
      {:reply, :ok, new_state}

    true ->
      Process.monitor(pid)
      state.historique |> Enum.reverse() |> Enum.each(fn msg -> send(pid, {:message, msg}) end)
      {:reply, :ok, %{state | clients: [pid | state.clients]}}

    false ->
      {:reply, {:error, :mauvais_password}, state}
  end
end

  # Quitter un salon
  def handle_call({:quitter, pid}, _from, state) do
    {:reply, :ok, %{state | clients: List.delete(state.clients, pid)}}
  end

  # BONUS
  def handle_call({:password, password}, _from, state) do
    hash = :crypto.hash(:sha256, password)
    {:reply, :ok, %{state | password: hash}}
  end

  def handle_cast({:broadcast, msg}, state) do
  # Envoie du msg a tous les clients actuellement dans le salon
    Enum.each(state.clients, &send(&1, {:message, msg}))
    # On ajoute le message en tete et oon garde que les 10 recents
    nouvel_historique = Enum.take([msg | state.historique], 10)
    {:noreply, %{state | historique: nouvel_historique}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    #Si le client crash on le retire de la liste
    {:noreply, %{state | clients: List.delete(state.clients, pid)}}
  end

  defp via(name), do: {:via, Registry, {MiniDiscord.Registry, name}}
end
