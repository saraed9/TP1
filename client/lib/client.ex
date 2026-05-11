defmodule Client do

  def main([host, port_str]) do
    start(host, String.to_integer(port_str))
  end

  def start(host, port) do
   connect_with_retry(host, port, 1)
  end
  #partie crypto
  defp get_cle, do: File.read!("../cle.bin")

  defp chiffrer(msg) do
    cle=get_cle()
    iv= :crypto.strong_rand_bytes(16)
    msg_c= :crypto.crypto_one_time(:aes_256_ctr, cle,iv,msg,true)
    iv <> msg_c
  end

  defp dechiffrer(donnees) do
    cle=get_cle()
    <<iv::binary-size(16),msg_chiffre::binary>> =donnees
    :crypto.crypto_one_time(:aes_256_ctr, cle, iv, msg_chiffre, false)
  end

  defp connect_with_retry(host, port, attempt) do
    opts = [:binary, packet: 0, active: false]
    case :gen_tcp.connect(String.to_charlist(host), port, opts) do
      {:ok, socket} ->
        IO.puts("Connecté au serveur !")
        rencontre(socket)
        receive_task=Task.async(fn -> receive_loop(socket, host, port) end)
        send_task=Task.async(fn -> send_loop(socket) end)
        Task.await(receive_task, :infinity)
        Task.await(send_task, :infinity)

      {:error, reason} ->
        IO.puts("Tentative #{attempt} échouée : #{reason}")
        :timer.sleep(2000) # Attendre 2 secondes
        connect_with_retry(host, port, attempt + 1)
    end
  end

  defp rencontre(socket) do
  recv_print(socket)   # Bienvenue sur MiniDiscord!
  recv_print(socket)   # Entrer ton pseudo :

  pseudo = IO.gets("") |> String.trim()
  :gen_tcp.send(socket, chiffrer(pseudo <> "\n"))#chiffree

  recv_print(socket)
  recv_print(socket)   # Rejoins un salon (ex:general) :

  salon = IO.gets("") |> String.trim()
  :gen_tcp.send(socket, chiffrer(salon <> "\n"))#chiffree

  recv_print(socket)   # Mot de passe du salon ... :
  password = IO.gets("") |> String.trim()
  :gen_tcp.send(socket, chiffrer(password <> "\n"))#chiffree

  recv_print(socket)   # Tu es dans #salon ...
  recv_print(socket)   # Commandes : ...
 end

  defp receive_loop(socket, host, port) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, donnees} ->
        IO.write(dechiffrer(donnees))
        receive_loop(socket,host,port)
        {:error, reason} ->
        IO.puts("Connexion perdue : (#{reason}). Reconnexion...")
        :gen_tcp.close(socket)
        connect_with_retry(host, port, 1)
    end
  end

  defp send_loop(socket) do
    case IO.gets("") do
      :eof -> :ok
      input ->
        case valider_message(input) do
          {:ok, msg} ->
            :gen_tcp.send(socket, chiffrer(msg <> "\n"))#chiffree
            send_loop(socket)
          {:error, reason} ->
            IO.puts("Attention : #{reason}")
            send_loop(socket)
        end
    end
  end

 defp recv_print(socket) do
    case :gen_tcp.recv(socket, 0, 2000) do  # 2 secondes
      {:ok, msg}        ->
        IO.write(dechiffrer(msg))
      {:error, :timeout} -> :ok  # pas de message, continuer
      {:error, reason}  -> IO.puts("Erreur : #{reason}")
    end
  end
  defp valider_message(msg) do
    trimmed=String.trim(msg)
    cond do
      trimmed == "" ->
        {:error, "Message vide"}
      byte_size(trimmed) > 500 ->
        {:error, "Message trop long (max 500 caractères)"}
      String.contains?(trimmed, ["\\","?","<",">","|","*",":","/", "\n"]) ->
        {:error, "Message contiengt des caracteres interdits"}
      true ->
        {:ok, trimmed}
    end
  end

end
