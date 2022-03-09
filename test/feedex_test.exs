defmodule FeedexTest do
  use ExUnit.Case
  doctest Feedex

  test "greets the world" do
    assert Feedex.hello() == :world
  end
end
