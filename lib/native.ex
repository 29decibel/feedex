defmodule Feedex.Native do
  @moduledoc """
  Native support of Feedex
  """

  use Rustler,
    otp_app: :feedex,
    crate: :feedex_native

  def parse_rss(_arg1), do: :erlang.nif_error(:nif_not_loaded)
  def parse_atom(_arg1), do: :erlang.nif_error(:nif_not_loaded)
end
