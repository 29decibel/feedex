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

defmodule TeslaClient do
  @moduledoc """
  Tesla client with Hackney and follow redirects
  """
  use Tesla

  adapter(Tesla.Adapter.Hackney)

  # defaults to 5
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 3)
end

defmodule Feedex do
  @moduledoc """
  Feedex is a RSS feed fetcher and parser
  """

  # https://gist.github.com/sasa1977/5967224
  import Record, only: [defrecord: 2, extract: 2]
  defrecord :xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")

  def parse_example_opml do
    xml = File.read!("./examples/Subscriptions-MineReads.opml")
    {doc, _} = xml |> :binary.bin_to_list() |> :xmerl_scan.string()

    :xmerl_xpath.string('//outline', doc)
    |> Enum.map(&attr(&1, "xmlUrl"))
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp parse_xml_feed(url, body) do
    case Feedex.Native.parse_rss(body) do
      %{"Err" => _err} ->
        case Feedex.Native.parse_atom(body) do
          %{"Err" => err} ->
            {:error, "Can not parse #{url} - #{err}"}

          {:error, err} ->
            {:error, "Can not parse #{url} - #{err}"}

          result ->
            parse_rss_result_map(result)
        end

      %{"Ok" => result} ->
        parse_rss_result_map(result)
    end
  end

  defp parse_json_feed(url, body) do
    case Jason.decode(body) do
      {:ok, result} ->
        parse_rss_result_map(result)

      _ ->
        IO.inspect("WARN: Can not parse #{url}, the headers might lie, so we try the xml version")
        parse_xml_feed(url, body)
    end
  end

  @json_header_value "application/json"

  def parse_feed_url(url) do
    case TeslaClient.get(url) do
      {:ok, %{body: body, headers: headers}} ->
        content_type =
          headers
          |> Enum.find_value(nil, fn {_k, v} ->
            String.contains?(v, @json_header_value)
          end)

        if content_type do
          parse_json_feed(url, body)
        else
          parse_xml_feed(url, body)
        end

      _ ->
        "Can not get #{url}"
    end
  end

  defp parse_rss_result_map(result) do
    # do something to the result
    IO.inspect(result |> Map.keys())
    count = result |> get_feed_items() |> Enum.count()
    IO.inspect("Total: #{count}")
  end

  def get_feed_items(%{"items" => items}), do: items
  def get_feed_items(%{"entries" => entries}), do: entries
  def get_feed_items(_), do: []

  def parse_all_example_urls do
    parse_example_opml() |> Enum.each(&parse_feed_url(&1))
  end

  def attr(node, name), do: node |> xpath('./@#{name}') |> extract_attr
  defp extract_attr([xmlAttribute(value: value)]), do: List.to_string(value)
  defp extract_attr(_), do: nil

  defp xpath(nil, _), do: []

  defp xpath(node, path) do
    :xmerl_xpath.string(to_char_list(path), node)
  end
end
