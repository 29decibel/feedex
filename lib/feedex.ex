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

  # https://github.com/bitwalker/timex/blob/main/docs/Parsing.md
  @time_parsers ["{ISO:Extended}", "{RFC822}", "{RFC1123}"]

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
    item = result |> get_feed_items() |> List.first() |> get_item_content()
    date = result |> get_feed_items() |> List.first() |> get_item_date() |> parse_date()

    if date == nil do
      # 01 Mar 2022 12:00 +0000
      # Tue, 24 March 2021 08:00:00 EST
      IO.inspect(
        "!!!!!!!!!!!!!can not parse #{result |> get_feed_items() |> List.first() |> get_item_date()}"
      )
    else
      IO.inspect(date)
    end

    if item == nil do
      IO.inspect(result |> get_feed_items() |> List.first())
    end

    IO.inspect("Total: #{count}")
  end

  ############### GRAB item content ########################
  defp get_item_content(%{
         "content" => %{
           value: value
         }
       })
       when not is_nil(value),
       do: value

  defp get_item_content(%{"content" => content}) when not is_nil(content), do: content

  defp get_item_content(%{
         "description" => %{
           value: value
         }
       })
       when not is_nil(value),
       do: value

  defp get_item_content(%{"description" => description}) when not is_nil(description),
    do: description

  defp get_item_content(%{"content_html" => content_html}), do: content_html

  defp get_item_content(_), do: nil

  ############################ GET ITEMS ####################################
  def get_feed_items(%{"items" => items}), do: items
  def get_feed_items(%{"entries" => entries}), do: entries
  def get_feed_items(_), do: []

  ############################# GET DATE #########################################

  defp get_item_date(%{"date_modified" => date_modified}) when is_binary(date_modified),
    do: date_modified

  defp get_item_date(%{"date_published" => date_published}) when is_binary(date_published),
    do: date_published

  defp get_item_date(%{"updated" => updated}) when is_binary(updated), do: updated

  defp get_item_date(%{"pub_date" => pub_date}) when is_binary(pub_date), do: pub_date

  # https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html#module-compound-directives
  def parse_date(date_string) do
    @time_parsers
    |> Enum.reduce(nil, fn date_format, parsed ->
      if parsed do
        parsed
      else
        case Timex.parse(date_string, date_format) do
          {:ok, parsed_date} -> parsed_date
          _ -> nil
        end
      end
    end)
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
