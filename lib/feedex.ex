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
  defmodule Item do
    defstruct id: nil, title: nil, date: nil, content: nil, link: nil, authors: []
  end

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
    IO.inspect(result)

    result
    |> get_feed_items()
    |> Enum.map(
      &%Item{
        id: get_item_id(&1),
        title: get_item_title(&1),
        date: get_item_date(&1) |> parse_date,
        content: get_item_content(&1),
        link: get_item_link(&1),
        authors: get_item_authors(&1)
      }
    )
  end

  ############### GRAB item content ########################
  defp get_item_content(%{
         "content" => %{
           "value" => value
         }
       })
       when is_binary(value),
       do: value

  defp get_item_content(%{"content" => content}) when is_binary(content), do: content

  defp get_item_content(%{
         "description" => %{
           "value" => value
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
  defp get_item_date(%{"published" => published}) when is_binary(published), do: published
  defp get_item_date(%{"pub_date" => pub_date}) when is_binary(pub_date), do: pub_date

  ##################### GET title ################################
  defp get_item_title(%{"title" => %{"value" => value}}) when is_binary(value), do: value
  defp get_item_title(%{"title" => title}) when is_binary(title), do: title
  defp get_item_title(_), do: "No title"

  ################# GET authors ####################
  defp get_item_authors(%{"authors" => authors}) when is_list(authors) and length(authors) > 0 do
    authors |> Enum.map(&get_author_name(&1)) |> Enum.reject(&is_nil(&1))
  end

  defp get_item_authors(%{"author" => author}) when is_binary(author), do: [author]
  defp get_item_authors(_), do: []

  defp get_author_name(%{"name" => name}), do: name
  defp get_author_name(_), do: nil

  ############### GET LINK #######################
  defp get_item_link(%{"links" => links}) when is_list(links) and length(links) > 0 do
    case links |> Enum.find(nil, &(&1["rel"] == "self")) do
      nil -> links |> List.first() |> Map.get("href")
      self_link -> self_link |> Map.get("href")
    end
  end

  defp get_item_link(%{"link" => link}), do: link
  defp get_item_link(%{"url" => url}), do: url

  ############# ID #########################
  defp get_item_id(%{"id" => id}) when is_binary(id), do: id
  defp get_item_id(%{"guid" => %{"value" => value}}) when is_binary(value), do: value
  # fallback using link as feed item id
  defp get_item_id(item), do: get_item_link(item)

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
    parse_example_opml() |> Enum.map(&parse_feed_url(&1))
  end

  def attr(node, name), do: node |> xpath('./@#{name}') |> extract_attr
  defp extract_attr([xmlAttribute(value: value)]), do: List.to_string(value)
  defp extract_attr(_), do: nil

  defp xpath(nil, _), do: []

  defp xpath(node, path) do
    :xmerl_xpath.string(to_char_list(path), node)
  end
end
