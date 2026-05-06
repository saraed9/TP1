defmodule MonProjetTest do
  use ExUnit.Case
  doctest MonProjet

  test "greets the world" do
    assert MonProjet.hello() == :world
  end
end
