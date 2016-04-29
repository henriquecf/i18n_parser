defmodule Translatable do
  defstruct [:original, :text, :key, :prefix, :suffix, :type]
  @type t :: %Translatable{original: String.t, text: String.t, key: String.t,
                           prefix: String.t, suffix: String.t, type: String.t}

  @prefix_pattern ~r{^(?<prefix>\"?[\,\.]?(\'s)?(--)?\s*)}
  @suffix_pattern ~r{(?<suffix>:?\s*\*?\,?\s*)$}

  @doc ~S"""
  Extracts the text, prefix, suffix and key from original text

  ## Examples

      iex> Translatable.from_original(" simple text: ")
      %Translatable{original: " simple text: ", text: "simple text", key: "simple_text", prefix: " ", suffix: ": ", type: "html"}

      iex> Translatable.from_original(". simple text: ")
      %Translatable{original: ". simple text: ", text: "simple text", key: "simple_text", prefix: ". ", suffix: ": ", type: "html"}

      iex> Translatable.from_original("simple, with comma. Text")
      %Translatable{original: "simple, with comma. Text", text: "simple, with comma. Text", key: "simple_with_comma_text", prefix: "", suffix: "", type: "html"}

      iex> Translatable.from_original("simple text: ")
      %Translatable{original: "simple text: ", text: "simple text", key: "simple_text", prefix: "", suffix: ": ", type: "html"}

      iex> Translatable.from_original(" simple text")
      %Translatable{original: " simple text", text: "simple text", key: "simple_text", prefix: " ", suffix: "", type: "html"}

      iex> Translatable.from_original("simple text")
      %Translatable{original: "simple text", text: "simple text", key: "simple_text", prefix: "", suffix: "", type: "html"}

      iex> Translatable.from_original("simple text *")
      %Translatable{original: "simple text *", text: "simple text", key: "simple_text", prefix: "", suffix: " *", type: "html"}

      iex> Translatable.from_original("simple text, ")
      %Translatable{original: "simple text, ", text: "simple text", key: "simple_text", prefix: "", suffix: ", ", type: "html"}

      iex> Translatable.from_original(", simple text: ")
      %Translatable{original: ", simple text: ", text: "simple text", key: "simple_text", prefix: ", ", suffix: ": ", type: "html"}

      iex> Translatable.from_original(", \"complex\" text: ")
      %Translatable{original: ", \"complex\" text: ", text: "\\\"complex\\\" text", key: "complex_text", prefix: ", ", suffix: ": ", type: "html"}

      iex> Translatable.from_original("'s simple text: ")
      %Translatable{original: "'s simple text: ", text: "simple text", key: "simple_text", prefix: "'s ", suffix: ": ", type: "html"}

      iex> Translatable.from_original("-- simple text: ")
      %Translatable{original: "-- simple text: ", text: "simple text", key: "simple_text", prefix: "-- ", suffix: ": ", type: "html"}

      iex> Translatable.from_original("\", simple text: ")
      %Translatable{original: "\", simple text: ", text: "simple text", key: "simple_text", prefix: "\", ", suffix: ": ", type: "html"}

      iex> Translatable.from_original("symbols @|/()[]{}':+%=!& removed")
      %Translatable{original: "symbols @|/()[]{}':+%=!& removed", text: "symbols @|/()[]{}':+%=!& removed", key: "symbols_removed", prefix: "", suffix: "", type: "html"}

  """
  def from_original(original_text, type \\ "html") do
    text = extract_text(original_text)
    key = key_from_text(text)
    %Translatable{original: original_text, text: text, prefix: extract_prefix(original_text), suffix: extract_suffix(original_text), key: key, type: type}
  end

  def replace_keys(string, translatable = %Translatable{type: "erb"}) do
    if String.length(translatable.prefix) > 0 || String.length(translatable.suffix) > 0 do
      Regex.replace(~r{(<%.*)["']([^\"]*#{Regex.escape(translatable.text)}[^\"]*)["'](.*%>)}, string, "\\1\"#{translatable.prefix}\#\{t(\".#{translatable.key}\")\}#{translatable.suffix}\"\\3")
    else
      Regex.replace(~r{(<%.*)["']([^\"]*#{Regex.escape(translatable.text)}[^\"]*)["'](.*%>)}, string, "\\1t(\".#{translatable.key}\")\\3")
    end
  end

  def replace_keys(string, translatable = %Translatable{type: "html"}) do
    Regex.replace(~r{(>[\s\n\,:]*)(#{Regex.escape(translatable.text)})([\s\n\,:]*<)}, string, "\\1<%= t(\".#{translatable.key}\") %>\\3")
  end

  defp key_from_text(text) do
    remove_quotes = Regex.replace(~r/\\\"/, text, "")
    Regex.replace(~r{[.,@/()\[\]|\{\}':\+%=!&]}, remove_quotes, "")
    |> String.downcase
    |> String.strip
    |> String.split(~r/\s+/)
    |> Enum.join("_")
  end

  defp extract_prefix(original_text) do
    Regex.named_captures(@prefix_pattern, original_text)
    |> Map.get("prefix")
  end

  defp extract_suffix(original_text) do
    Regex.named_captures(@suffix_pattern, original_text)
    |> Map.get("suffix")
  end

  defp extract_text(original_text) do
    text_without_prefix = Regex.replace(@prefix_pattern, original_text, "")
    text = Regex.replace(@suffix_pattern, text_without_prefix, "")
    Regex.replace(~r/\"/, text, "\\\"")
  end
end
