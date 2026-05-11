cle= :crypto.strong_rand_bytes(32)
File.write!("cle.bin", cle)
IO.puts("Cle generee: #{Base.encode16(cle)}")
