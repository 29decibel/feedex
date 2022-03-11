defmodule OpmlParser do
  # https://gist.github.com/sasa1977/5967224
  import Record, only: [defrecord: 2, extract: 2]
  defrecord :xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")

  def attr(node, name), do: node |> xpath('./@#{name}') |> extract_attr
  defp extract_attr([xmlAttribute(value: value)]), do: List.to_string(value)
  defp extract_attr(_), do: nil

  defp xpath(nil, _), do: []

  defp xpath(node, path) do
    :xmerl_xpath.string(to_char_list(path), node)
  end

  def parse_example_opml do
    xml = File.read!("./examples/Subscriptions-MineReads.opml")
    {doc, _} = xml |> :binary.bin_to_list() |> :xmerl_scan.string()

    :xmerl_xpath.string('//outline', doc)
    |> Enum.map(&attr(&1, "xmlUrl"))
    |> Enum.filter(&(!is_nil(&1)))
  end
end
