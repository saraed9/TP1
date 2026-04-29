defmodule MiniDiscord.ClientHandler do
  require Logger

  @doc """
  Demarrage du client :
    - affiche de bienvenue, demande du pseudo, affichage des salons et demande du salon à rejoindre
    - lance la relation pseudo, salon : rejoindre_salon(socket, pseudo, salon)
  """
  def start(socket) do
    :gen_tcp.send(socket, "Bienvenue sur MiniDiscord!\r\n")
    pseudo = choisir_pseudo(socket)

    :gen_tcp.send(socket, "Salon disponibles : #{salons_dispo()}\r\n")
    :gen_tcp.send(socket, "Rejoins un salon (ex:general) : ")
    {:ok, salon} = :gen_tcp.recv(socket, 0)
    salon = String.trim(salon)

    rejoindre_salon(socket, pseudo, salon)
  end

  defp choisir_pseudo(socket) do
    :gen_tcp.send(socket, "Entrer ton pseudo : ")
    {:ok, pseudo} = :gen_tcp.recv(socket, 0)
    pseudo = String.trim(pseudo)
    # verification dans la table ETS  pour l'unicite du pseudo
    if pseudo_disponible?(pseudo) do
      reserver_pseudo(pseudo)
      pseudo
    else
      :gen_tcp.send(socket, "Pseudo \"#{pseudo}\" deja pris, veuillez choisir un autre.\r\n")
      choisir_pseudo(socket) # jusqu'a avoir un pseudo valide
    end
  end

  defp rejoindre_salon(socket, pseudo, salon) do
  # si le salon n'existe pas dans le Registry on le cree 
  case Registry.lookup(MiniDiscord.Registry, salon) do
    [] -> DynamicSupervisor.start_child(MiniDiscord.SalonSupervisor, {MiniDiscord.Salon, salon})
    _  -> :ok
  end

  # Demander le mot de passe au client
  :gen_tcp.send(socket, "Mot de passe du salon (appuie sur Entrée si aucun) : ")
  {:ok, password} = :gen_tcp.recv(socket, 0)
  password = String.trim(password)
  password = if password == "", do: nil, else: password

  case MiniDiscord.Salon.rejoindre(salon, self(), password) do
    :ok ->
      MiniDiscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
      :gen_tcp.send(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")
      :gen_tcp.send(socket, "Commandes : /list /join <salon> /quit\r\n")
      loop(socket, pseudo, salon)
    {:error, :mauvais_password} ->
      :gen_tcp.send(socket, "❌ Mot de passe incorrect !\r\n")
      loop(socket, pseudo, salon)
  end
end

  defp loop(socket, pseudo, salon) do
    # Verifie si des messages sont arrives du salon
    receive do
      {:message, msg} -> :gen_tcp.send(socket, msg)
      after 0 -> :ok #ne pas bloquer si y a pas de message
    end
    # ecout des messages envoyes
    case :gen_tcp.recv(socket, 0, 100) do
      {:ok, msg} ->
        msg = String.trim(msg)
        # detecter le "/" 
        if String.starts_with?(msg, "/") do
          gerer_commande(socket, pseudo, salon, msg)
        else
        # message normale 
          MiniDiscord.Salon.broadcast(salon, "[#{pseudo}] #{msg}\r\n")
          loop(socket, pseudo, salon)
        end

      {:error, :timeout} ->
        loop(socket, pseudo, salon)# pour maintenir la connecxion

      {:error, reason} ->
      # deconnexion
        Logger.info("Client déconnecté : #{inspect(reason)}")
        deconnecter(pseudo, salon)
    end
  end

  defp gerer_commande(socket, pseudo, salon, commande) do
    case commande do
      "/list" ->
        liste = MiniDiscord.Salon.lister() |> Enum.join(", ")
        :gen_tcp.send(socket, " Salon disponibles : #{liste}\r\n")
        loop(socket, pseudo, salon)

      "/quit" ->
        :gen_tcp.send(socket, " Adiosss #{pseudo} !👋\r\n")
        deconnecter(pseudo, salon)

      "/join" <> nouveau_salon ->
        nouveau_salon = String.trim(nouveau_salon)
        # pour quitter le salon ancien
        MiniDiscord.Salon.broadcast(salon, "👋 #{pseudo} a quitte ##{salon}\r\n")
        MiniDiscord.Salon.quitter(salon, self())
        # Rejoindre le nouveau
        rejoindre_salon(socket, pseudo, nouveau_salon)

      _ ->
        :gen_tcp.send(socket, " Commande inconnue. Commandes : /list  /join <salon>  /quit\r\n")
        loop(socket, pseudo, salon)
    end
  end

  defp deconnecter(pseudo, salon) do
    MiniDiscord.Salon.broadcast(salon, " #{pseudo} a quitte ##{salon}\r\n")
    MiniDiscord.Salon.quitter(salon, self())
    liberer_pseudo(pseudo)
  end

  #retourne true si le pseudo n'est pas pris
  defp pseudo_disponible?(pseudo) do
    :ets.lookup(:pseudos, pseudo) == []
  end

  # Reservation du pseudo en l'associant au PID courant
  defp reserver_pseudo(pseudo) do
    :ets.insert(:pseudos, {pseudo, self()})
  end

  #liberer le pseudo
  defp liberer_pseudo(pseudo) do
    :ets.delete(:pseudos, pseudo)
  end

  # Retourne la liste des salons
  defp salons_dispo do
    case MiniDiscord.Salon.lister() do
      []     -> "aucun (tu seras le premier !)"
      salons -> Enum.join(salons, ", ")
    end
  end
end