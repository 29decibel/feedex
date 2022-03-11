defmodule TeslaClient do
  @moduledoc """
  Tesla client with Hackney and follow redirects
  """
  use Tesla

  adapter(Tesla.Adapter.Hackney)

  # defaults to 5
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 3)
end
