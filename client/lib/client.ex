defmodule Client do

  def main([host, port_str]) do
    start(host, String.to_integer(port_str))
  end

  def start(host, port) do
    socket = connect_with_retry(host, port, 1) #on essaye la connection
    recontre(socket) #on rencontre le serveur
    recieve_task = Task.async(fn -> Client.receive_loop(socket) end) #on lance la boucle de reception
    send_task = Task.async(fn -> Client.send_loop(socket) end) #on lance la boucle d'envoi
    Task.await(recieve_task, :infinity)
    Task.await(send_task, :infinity)
  end

  defp connect_with_retry(host, port, attempt) do
    opts = [:binary, packet: 0, active: false]
    case :gen_tcp.connect(String.to_charlist(host), port, opts) do
      {:ok, socket} ->
        IO.puts("Connecté au serveur !")
        socket

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
  :gen_tcp.send(socket, pseudo <> "\n")

  recv_print(socket)
  recv_print(socket)   # Rejoins un salon (ex:general) :

  salon = IO.gets("") |> String.trim()
  :gen_tcp.send(socket, salon <> "\n")

  recv_print(socket)   # Mot de passe du salon ... :
  password = IO.gets("") |> String.trim()
  :gen_tcp.send(socket, password <> "\n")

  recv_print(socket)   # Tu es dans #salon ...
  recv_print(socket)   # Commandes : ...
end

  defp receive_loop(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, msg} ->
        IO.write(msg)
        receive_loop(socket)
      {:error, reason} ->
        IO.puts("Connection perdue (#{reason}). Reconnecion ...")
        :gen_tcp.close(socket)
        start("localhost", 4000) # Reconnecter au serveur
    end
  end

  defp send_loop(socket) do
    case IO.gets("") do
      :eof -> :ok
      input ->
        msg = String.trim(input) <> "\n"
        case :gen_tcp.send(socket, msg) do
          :ok -> send_loop(socket)
          {:error, _reason} -> :ok
        end
    end
  end

 defp recv_print(socket) do
    case :gen_tcp.recv(socket, 0, 2000) do  # 2 secondes
      {:ok, msg}        -> IO.write(msg)
      {:error, :timeout} -> :ok  # pas de message, continuer
      {:error, reason}  -> IO.puts("Erreur : #{reason}")
    end
  end
  defp valider_message(msg) do
    case String.trim(msg) do
      "" -> {:error, "Message vide"} # cas d'un message vide
      trimmed -> {:ok, trimmed}
      #cas message trop long (max 500 caractères)
      trimmed when byte_size(trimmed) > 500 -> {:error, "Message trop long"}
      _ -> {:ok, msg}
      # cas d'un message contenant des characteres comme: \ ?<> ...
      trimmed when String.contains?(trimmed, ["\\", "?", "<", ">", "|", "*", ":"]) ->
        {:error, "Message contient des caractères interdits"}
      _ -> {:ok, msg}
    end
  end

end
