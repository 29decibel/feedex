defmodule FeedExtractor do
  @moduledoc """
  Extract sematic content from the feed map
  """

  def get_feed_title(%{
        "title" => %{
          "value" => value
        }
      })
      when is_binary(value),
      do: value

  def get_feed_title(%{"title" => title}) when is_binary(title), do: title

  def get_feed_link(%{"link" => link}) when is_binary(link), do: link

  def get_feed_link(%{"home_page_url" => home_page_url}) when is_binary(home_page_url),
    do: home_page_url

  def get_feed_link(%{"links" => links}) when is_list(links) and length(links) > 0 do
    find_by_attr = fn name, value ->
      links |> Enum.filter(&(Map.get(&1, name, nil) == value))
    end

    html_url = find_by_attr.("mime_type", "text/html")
    alternative_url = find_by_attr.("rel", "alternative")

    cond do
      length(html_url) > 0 -> html_url |> List.first() |> Map.get("href")
      length(alternative_url) > 0 -> alternative_url |> List.first() |> Map.get("href")
      true -> links |> List.first() |> Map.get("href")
    end
  end

  ############### GRAB item content ########################
  def get_item_content(%{
        "content" => %{
          "value" => value
        }
      })
      when is_binary(value),
      do: value

  def get_item_content(%{"content" => content}) when is_binary(content), do: content

  def get_item_content(%{
        "description" => %{
          "value" => value
        }
      })
      when not is_nil(value),
      do: value

  def get_item_content(%{"description" => description}) when not is_nil(description),
    do: description

  def get_item_content(%{"content_html" => content_html}), do: content_html

  def get_item_content(_), do: nil

  ############################ GET ITEMS ####################################
  def get_feed_items(%{"items" => items}), do: items
  def get_feed_items(%{"entries" => entries}), do: entries
  def get_feed_items(_), do: []

  ############################# GET DATE #########################################

  def get_item_date(%{"date_modified" => date_modified}) when is_binary(date_modified),
    do: date_modified

  def get_item_date(%{"date_published" => date_published}) when is_binary(date_published),
    do: date_published

  def get_item_date(%{"updated" => updated}) when is_binary(updated), do: updated
  def get_item_date(%{"published" => published}) when is_binary(published), do: published
  def get_item_date(%{"pub_date" => pub_date}) when is_binary(pub_date), do: pub_date

  ##################### GET title ################################
  def get_item_title(%{"title" => %{"value" => value}}) when is_binary(value), do: value
  def get_item_title(%{"title" => title}) when is_binary(title), do: title
  def get_item_title(_), do: "No title"

  ################# GET authors ####################
  def get_item_authors(%{"authors" => authors}) when is_list(authors) and length(authors) > 0 do
    authors |> Enum.map(&get_author_name(&1)) |> Enum.reject(&is_nil(&1))
  end

  def get_item_authors(%{"author" => author}) when is_binary(author), do: [author]
  def get_item_authors(_), do: []

  def get_author_name(%{"name" => name}), do: name
  def get_author_name(_), do: nil

  ############### GET LINK #######################
  def get_item_link(%{"links" => links}) when is_list(links) and length(links) > 0 do
    case links |> Enum.find(nil, &(&1["rel"] == "self")) do
      nil -> links |> List.first() |> Map.get("href")
      self_link -> self_link |> Map.get("href")
    end
  end

  def get_item_link(%{"link" => link}), do: link
  def get_item_link(%{"url" => url}), do: url

  ############# ID #########################
  def get_item_id(%{"id" => id}) when is_binary(id), do: id
  def get_item_id(%{"guid" => %{"value" => value}}) when is_binary(value), do: value
  # fallback using link as feed item id
  def get_item_id(item), do: get_item_link(item)
end
