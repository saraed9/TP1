defmodule MiniDiscord.ClientHandler do
  require Logger

  @doc """
  Demarrage du client :
    - affiche de bienvenue, demande du pseudo, affichage des salons et demande du salon à rejoindre
    - lance la relation pseudo, salon : rejoindre_salon(socket, pseudo, salon)
  """
  #Cette partie est la partie de crypto:
  defp get_cle do
    [{:cle,cle}]= :ets.lookup(:crypto_config, :cle)
    cle
  end

  defp chiffrer(msg)do
    cle= get_cle()
    iv= :crypto.strong_rand_bytes(16)
    msg_c= :crypto.crypto_one_time(:aes_256_ctr, cle,iv,msg,true)
    Base.encode64(iv <> msg_c) <> "\r\n"
  end

  defp dechiffrer(donnees) do
    cle=get_cle()
    {:ok, binaire} = Base.decode64(String.trim(donnees))
    <<iv::binary-size(16),msg_chiffre::binary>> =binaire
    :crypto.crypto_one_time(:aes_256_ctr, cle, iv, msg_chiffre, false)
  end

  defp recv_dec(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, donnees} -> {:ok, dechiffrer(donnees)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp recv_dec(socket,timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, donnees} -> {:ok, dechiffrer(donnees)}
      {:error, reason} -> {:error, reason}
    end
  end

   defp send_enc(socket, msg) do
    :gen_tcp.send(socket, chiffrer(msg))
  end
  def start(socket) do
    send_enc(socket, "Bienvenue sur MiniDiscord!\r\n")
    pseudo = choisir_pseudo(socket)

    send_enc(socket, "Salon disponibles : #{salons_dispo()}\r\n")
    send_enc(socket, "Rejoins un salon (ex:general) : ")
    {:ok, salon} = recv_dec(socket)
    salon = String.trim(salon)

    rejoindre_salon(socket, pseudo, salon)
  end

  defp choisir_pseudo(socket) do
    send_enc(socket, "Entrer ton pseudo : ")
    {:ok, pseudo} = recv_dec(socket)
    pseudo = String.trim(pseudo)
    # verification dans la table ETS  pour l'unicite du pseudo
    if pseudo_disponible?(pseudo) do
      reserver_pseudo(pseudo)
      pseudo
    else
      send_enc(socket, "Pseudo \"#{pseudo}\" deja pris, veuillez choisir un autre.\r\n")
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
  send_enc(socket, "Mot de passe du salon (appuie sur Entrée si aucun) : ")
  {:ok, password} = recv_dec(socket)
  password = String.trim(password)
  password = if password == "", do: nil, else: password

  case MiniDiscord.Salon.rejoindre(salon, self(), password) do
    :ok ->
      MiniDiscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
      send_enc(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")
      send_enc(socket, "Commandes : /list /join <salon> /quit\r\n")
      loop(socket, pseudo, salon)
    {:error, :mauvais_password} ->
      send_enc(socket, "❌ Mot de passe incorrect !\r\n")
      loop(socket, pseudo, salon)
  end
end

  defp loop(socket, pseudo, salon) do
    # Verifie si des messages sont arrives du salon
    receive do
      {:message, msg} ->  send_enc(socket, msg <> "\n")
      after 0 -> :ok #ne pas bloquer si y a pas de message
    end
    # ecout des messages envoyes
    case recv_dec(socket, 100) do
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
        send_enc(socket, " Salon disponibles : #{liste}\r\n")
        loop(socket, pseudo, salon)

      "/quit" ->
        send_enc(socket, " Adiosss #{pseudo} !👋\r\n")
        deconnecter(pseudo, salon)

      "/join" <> nouveau_salon ->
        nouveau_salon = String.trim(nouveau_salon)
        # pour quitter le salon ancien
        MiniDiscord.Salon.broadcast(salon, "👋 #{pseudo} a quitte ##{salon}\r\n")
        MiniDiscord.Salon.quitter(salon, self())
        # Rejoindre le nouveau
        rejoindre_salon(socket, pseudo, nouveau_salon)

      _ ->
        send_enc(socket, " Commande inconnue. Commandes : /list  /join <salon>  /quit\r\n")
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
