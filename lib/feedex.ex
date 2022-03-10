defmodule Feedex.Native do
  use Rustler,
    otp_app: :feedex,
    crate: :feedex_native

  def parse_rss(_arg1), do: :erlang.nif_error(:nif_not_loaded)
  def parse_atom(_arg1), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule TeslaClient do
  use Tesla

  adapter(Tesla.Adapter.Hackney)

  # defaults to 5
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 3)
end

defmodule Feedex do
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

  def parse_feed_url(url) do
    case TeslaClient.get(url) do
      {:ok, %{body: body, headers: headers}} ->
        content_type =
          headers
          |> Enum.find_value(nil, fn {_k, v} ->
            String.contains?(v, "application/json")
          end)

        if content_type do
          result = Jason.decode!(body)
          IO.inspect(result |> Map.keys())
        else
          case Feedex.Native.parse_rss(body) do
            %{"Err" => _err} ->
              case Feedex.Native.parse_atom(body) do
                %{"Err" => err} ->
                  IO.inspect("Can not parse #{url} - #{err}")

                {:error, err} ->
                  IO.inspect("Can not parse #{url} - #{err}")

                r ->
                  IO.inspect(r |> Map.keys())
                  nil
              end

            %{"Ok" => result} ->
              IO.inspect(result |> Map.keys())

              {:ok, result}
          end
        end

      _ ->
        "Can not get #{url}"
    end
  end

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
