defmodule I18nParser do
  @html_patterns [
    ~r{^\s*$},
    ~r/&\w{4,5};/,
    ~r{\s*[\w-]*\s*=\s*"*(.*?)"*},
    ~r/^\s*[\?\:\,\!\"\-\#\-\.\(\)\_\/\|\+\=\[\]\@\s]+\s*$/,
    ~r/\w*\s*=*\s*"*\/[\w.<>%=\/]+\/*"*/,
    ~r{params\[\:\w+\]},
    ~r{^\+?\d+\s*$},
    ~r(^\s*\d\d%\s*$),
    ~r/^\s*?\$?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\s*$/,
    ~r/^\s*\$\s*$/,
    ~r/^\s*null\s*$/i,
    ~r/^\s*'s\s*$/i,
    ~r{\s*<%(.*?)%>\s*}
  ]
  @erb_patterns [
    ~r{render\s+["'][#\w\s.]+["']}sm,
    ~r{class\s*=\s*["']<%(.*?)%>["']}sm,
    ~r{(class|id|controller|action|novalidate|equalTo|target|disabled):\s*["'(][#().&!='?:\w\s-]*(#\{.*\})*[#().&!='?:\w\s-]*["')]},
    ~r{:(class|id|controller|action|novalidate|equalTo|target|disabled)\s*=>\s*["'(][#().&!='?:\w\s-]*(#\{.*\})*[#().&!='?:\w\s-]*["')]},
    ~r{""},
    ~r{["']\/[\w\/#.@\{\}]+["']},
    ~r{["'][\w\/#.@\{\}]+\/[\w\/#.@\{\}]+["']},
    ~r{(where|order)\(".*"\)},
    ~r{(where|order)\('.*'\)},
    ~r{".*(\w_)+.*"},
    ~r{"[#@!\.\#]+"}
  ]
  @doc ~S"""
  Parse a string searching for text to be translated inside erb structures

  ## Examples

      iex> I18nParser.parse_erb("<%= title \"A page title\" %>")
      [%Translatable{original: "A page title", text: "A page title", key: "a_page_title", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= title \"A page title\" \"Other string\" %>")
      [%Translatable{original: "A page title", text: "A page title", key: "a_page_title", prefix: "", suffix: "", type: "erb"},
      %Translatable{original: "Other string", text: "Other string", key: "other_string", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= title \"A page title\" \"Other string\" %><% title \"some text\" %>")
      [%Translatable{original: "A page title", text: "A page title", key: "a_page_title", prefix: "", suffix: "", type: "erb"},
      %Translatable{original: "Other string", text: "Other string", key: "other_string", prefix: "", suffix: "", type: "erb"},
      %Translatable{original: "some text", text: "some text", key: "some_text", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= title \"A page title\" \"Other string\" %>\"ignored text\"<% title \"some text\" %>")
      [%Translatable{original: "A page title", text: "A page title", key: "a_page_title", prefix: "", suffix: "", type: "erb"},
      %Translatable{original: "Other string", text: "Other string", key: "other_string", prefix: "", suffix: "", type: "erb"},
      %Translatable{original: "some text", text: "some text", key: "some_text", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= title \"A page title\" \n%>")
      [%Translatable{original: "A page title", text: "A page title", key: "a_page_title", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= title \"A page \ntitle\" %>")
      [%Translatable{original: "A page \ntitle", text: "A page \ntitle", key: "a_page_title", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= render \"A page \ntitle\" %>")
      []

      iex> I18nParser.parse_erb("<a data-class=\"<%= \"A page \ntitle\" %>\"></a><a class='<%= 'A page \ntitle' %>'></a></a><a class  = '<%= 'A page \ntitle' %>'></a>")
      []

      iex> I18nParser.parse_erb("<%= f.button \"\", class: \"A page \ntitle\", :class=> \"A page\" %>")
      []

      iex> I18nParser.parse_erb("<%= f.button \"\/page\/html\" \"page\/html\" \"page\/html\/\" \"\/page\/html\/\"%>")
      []

      iex> I18nParser.parse_erb("<%= f.text_area :content, :id => \"comment-text\", :class => \"required \#\{\"disabled\" if (commentable.first_publish && page != 'manage')\}\", :placeholder => \"Leave a comment\", :disabled => ((commentable.first_publish && page != 'manage') ?  true :  false) %>")
      [%Translatable{original: "Leave a comment", text: "Leave a comment", key: "leave_a_comment", prefix: "", suffix: "", type: "erb"}]

      iex> I18nParser.parse_erb("<%= f.where(\"Some text\").order(\"other text\") \"@#.\" %>")
      []

      iex> I18nParser.parse_erb("<%= \"wicked_games game\" %>")
      []
  """
  def parse_erb(string) do
    Regex.scan(~r{<%(.*?)%>}sm, remove_undesired_patterns(string), capture: :all_but_first)
    |> List.flatten
    |> Enum.map(&(Regex.scan(~r{["'](.*?)["']}sm, &1, capture: :all_but_first)))
    |> List.flatten
    |> Enum.map(&(Translatable.from_original(&1, "erb")))
  end

  @doc ~S"""
  Parse a string searching for text to be translated inside html structures

  ## Examples

      iex> I18nParser.parse_html("<a>Show page</a>")
      [%Translatable{original: "Show page", text: "Show page", key: "show_page", prefix: "", suffix: "", type: "html"}]

      iex> I18nParser.parse_html("<a class=\"required\"></a>")
      []

      iex> I18nParser.parse_html("<p> <span>  \n    See in<br>the text below   </span></p>")
      [%Translatable{original: "  \n    See in", text: "See in", key: "see_in", prefix: "  \n    ", suffix: "", type: "html"},
      %Translatable{original: "the text below   ", text: "the text below", key: "the_text_below", prefix: "", suffix: "   ", type: "html"}]
  """
  def parse_html(string) do
    Regex.scan(~r{>([^<>]+)<}sm, string, capture: :all_but_first)
    |> List.flatten
    |> Enum.filter(fn(line) ->
      Enum.reduce(@html_patterns, true, fn(pattern, match) ->
        !Regex.match?(pattern, line) && match
      end)
    end)
    |> Enum.map(&(Translatable.from_original(&1, "html")))
  end

  @doc ~S"""
  Replace string by the corresponding I18n key

  ## Examples

      iex> I18nParser.replace_keys("<%= f.button \"A text\" %>", [%Translatable{original: "A text", text: "A text", key: "a_text", prefix: "", suffix: "", type: "erb"}])
      "<%= f.button t(\".a_text\") %>"
  """
  def replace_keys(string, translatables) do
    Enum.reduce(translatables, string, fn(translatable, s) ->
      Translatable.replace_keys(s, translatable)
    end)
  end

  def parse_file(file_path) do
    File.open(file_path, [:read, :write], fn(file) ->
      string = IO.read(file, :all)
      translatables = parse_erb(string) ++ parse_html(string)
      new_string = replace_keys(string, translatables)
      File.write(file_path, new_string)
      locale_for(translatables, file_path)
      locale_for(translatables, file_path, "pt-BR")
    end)
  end

  def locale_for(translatables, file_path, locale \\ "en") do
    yml_path = Path.relative_to(file_path, "/Users/ivan/code/can2/app/views")
    yml_dir = Path.dirname(yml_path)
    yml_file = Path.basename(yml_path, ".html.erb")
    file_name = String.replace_leading(yml_file, "_", "")
    File.mkdir("/Users/ivan/code/can2/config/locales/views/#{yml_dir}")
    File.touch("/Users/ivan/code/can2/config/locales/views/#{yml_dir}/#{yml_file}.#{locale}.yml")
    File.open("/Users/ivan/code/can2/config/locales/views/#{yml_dir}/#{yml_file}.#{locale}.yml", [:write], fn(file) ->
      IO.write(file, "#{locale}:\n  #{yml_dir}:\n    #{file_name}:\n")
      translatables
      |> Enum.map(&(IO.write(file, "      #{&1.key}: \"#{&1.text}\"\n")))
    end)
  end

  defp remove_undesired_patterns(string) do
    Enum.reduce(@erb_patterns, string, &(Regex.replace(&1, &2, "")))
  end
end
