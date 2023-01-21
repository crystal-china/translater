require "option_parser"
require "./translater"

enum TargetLanguage
  Chinese
  English
end

enum Browser
  Firefox
end

enum Engine
  Youdao
  Tencent
  Ali
  Baidu
end

target_language : TargetLanguage? = nil
debug_mode = false
content = ""
browser = Browser::Firefox
engine_list = Engine.values.shuffle![0..0]
timeout_seconds : Int32 = 10

stdin = [] of String

if STDIN.info.type.pipe?
  while (input = STDIN.gets)
    stdin << input
  end
  content = stdin.join("\n").strip
else
  ARGV << "--help" if ARGV.empty?
end

OptionParser.parse do |parser|
  parser.banner = <<-USAGE
Usage: translater <option> content
USAGE

  # parser.on(
  #       "-t TARGET",
  #       "--target=TARGET",
  #       "Specify target language, support zh-CN|en for now.
  # default is translate English to Chinese.
  # Youdao don't support this option.
  # "
  #     ) do |target|
  #       target_language = TargetLanguage.parse?(target)

  #       if target_language.nil?
  #         STDERR.puts "Supported options: #{TargetLanguage.names.map(&.downcase).join ", "}"
  #         exit 1
  #       end
  #     end

  parser.on(
    "-b BROWSER",
    "--browser=BROWSER",
    "Specify browser used for scrap, only support firefox for now, default is firefox.
") do |b|
    value = Browser.parse?(b)

    if value.nil?
      STDERR.puts "Supported options: #{Browser.names.map(&.downcase).join ", "}"
      exit 1
    else
      browser = value
    end
  end

  parser.on(
    "-e ENGINE",
    "--engine=ENGINE",
    "Specify engine used for translate, support youdao,tencent,ali,baidu.
multi-engine is possible, split it with comma, e.g. -e youdao,tencent
") do |e|
    inputs = e.split(",")
    engine_list = [] of Engine

    inputs.each do |input|
      if (engine = Engine.parse?(input))
        engine_list << engine
      else
        STDERR.puts "Supported options: #{Engine.names.map(&.downcase).join ", "}"
        exit 1
      end
    end
  end

  parser.on(
    "--timeout=SECONDS",
    "Specify timeout for get translate result, default is 10 seconds") do |seconds|
    timeout_seconds = seconds.to_i
  end

  parser.unknown_args do |args|
    if !STDIN.info.type.pipe?
      if args.empty?
        STDERR.puts "Please specify translate content. e.g. translater 'hello, China!'"
        exit
      else
        if args.first.blank?
          STDERR.puts "Translate content must be present. e.g. translater 'hello, China!'"
          exit
        end

        content = args.first.strip
      end
    end
  end

  parser.on("-D", "--debug", "Debug mode") do
    debug_mode = true
    timeout_seconds = 100000 # disable timeout if debug mode
  end

  parser.on("-h", "--help", "Show this help message and exit") do
    STDERR.puts parser
    exit
  end

  parser.on("-v", "--version", "Show version") do
    STDERR.puts Translater::VERSION
    exit
  end

  parser.invalid_option do |flag|
    STDERR.puts "Invalid option: #{flag}.\n\n"
    STDERR.puts parser
    exit 1
  end

  parser.missing_option do |flag|
    STDERR.puts "Missing option for #{flag}\n\n"
    STDERR.puts parser
    exit 1
  end
end

if target_language.nil?
  if content =~ /\p{Han}/
    target_language = TargetLanguage::English
  else
    target_language = TargetLanguage::Chinese
  end
end

Translater.new(
  content: content,
  target_language: target_language,
  debug_mode: debug_mode,
  browser: browser,
  engine_list: engine_list,
  timeout_seconds: timeout_seconds
)
