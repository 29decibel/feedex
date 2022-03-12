defmodule Feedex.FaviconFinder do
  @moduledoc """
  Find the favicon path of given HTML or website url
  https://developers.google.com/search/docs/advanced/appearance/favicon-in-search

  How to get high resolution website logo (favicon) for a given URL
  https://stackoverflow.com/questions/21991044/how-to-get-high-resolution-website-logo-favicon-for-a-given-url

  Do-it-yourself algorithm
  1. Look for Apple touch icon declarations in the code, such as <link rel="apple-touch-icon" href="/apple-touch-icon.png">. Theses pictures range from 57x57 to 152x152. See Apple specs for full reference.
  2. Even if you find no Apple touch icon declaration, try to load them anyway, based on Apple naming convention. For example, you might find something at /apple-touch-icon.png. Again, see Apple specs for reference.
  3. Look for high definition PNG favicon in the code, such as <link rel="icon" type="image/png" href="/favicon-196x196.png" sizes="196x196">. In this example, you have a 196x196 picture.
  4. Look for Windows 8 / IE10 and Windows 8.1 / IE11 tile pictures, such as <meta name="msapplication-TileImage" content="/mstile-144x144.png">. These pictures range from 70x70 to 310x310, or even more. See these Windows 8 and Windows 8.1 references.
  5. Look for /browserconfig.xml, dedicated to Windows 8.1 / IE11. This is the other place where you can find tile pictures. See Microsoft specs.
  6. Look for the og:image declaration such as <meta property="og:image" content="http://somesite.com/somepic.png"/>. This is how a web site indicates to FB/Pinterest/whatever the preferred picture to represent it. See Open Graph Protocol for reference.
  7. At this point, you found no suitable logo... damned! You can still load all pictures in the page and make a guess to pick the best one.
  Note: Steps 1, 2 and 3 are basically what Chrome does to get suitable icons for bookmark and home screen links. Coast by Opera even use the MS tile pictures to get the job done. Read this list to figure out which browser uses which picture (full disclosure: I am the author of this page).

  """

  @icon_selector [
    "link[rel=apple-touch-icon]",
    "link[rel=icon]",
    "link[rel=\"shortcut icon\"]",
    "link[rel=\"SHORTCUT ICON\"]",
    "meta[property=\"og:image\"]"
  ]

  def find_favicon_by_html(url, html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        @icon_selector
        |> Enum.reduce(nil, fn ele, acc ->
          case acc do
            acc when is_list(acc) and length(acc) > 0 ->
              acc

            _ ->
              document |> Floki.find(ele)
          end
        end)
        |> extract_image_url()

      _ ->
        nil
    end
  end

  defp extract_image_url(found_tags) when is_list(found_tags) and length(found_tags) > 0 do
    found_tags |> List.first() |> extract_image_url_from_tag()
  end

  defp extract_image_url(_), do: nil

  defp extract_image_url_from_tag({"meta", _, _} = tag), do: tag |> Floki.attribute("content")
  defp extract_image_url_from_tag({"link", _, _} = tag), do: tag |> Floki.attribute("href")

  def find_favicon(url) do
    case TeslaClient.get(url) do
      {:ok, %{body: body}} ->
        find_favicon_by_html(url, body)

      _ ->
        nil
    end
  end
end
