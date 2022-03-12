defmodule Feedex.ArticleParser do
  @moduledoc """
  Wrapper around mercury-parser cli
  https://github.com/postlight/mercury-parser
  npm i -g @postlight/mercury-parser
  """

  def parse_article(url) do
    case System.cmd("mercury-parser", [url]) do
      {result, 0} ->
        Jason.decode(result)

      _ ->
        {:error, "Error when calling mercury-parser cli."}
    end
  end
end
