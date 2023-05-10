require "option_parser"
require "./translater"
require "db"
require "sqlite3"

DB_FILE_ROOT = "#{Process.executable_path.as(String)}/../.."
DB_FILE      = "sqlite3:#{File.expand_path(DB_FILE_ROOT)}/profile.db"

enum TargetLanguage
  Chinese
  English
end

enum Browser
  Firefox
  Chrome
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
browser = Browser::Chrome
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
    "Specify browser used for scrap, support Firefox and Chrome, default is firefox.
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
    "-A",
    "Use all known engine for translate, can be used for profile purpose.") do
    engine_list = Engine.values
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

  parser.on("--profile", "Create profile dbs for translate engines") do
    engine_names = Engine.names.map(&.downcase)
    if File.exists? DB_FILE.split(':')[1]
      DB.connect DB_FILE do |db|
        ary = [] of String

        engine_names.each do |engine_name|
          db.query "select avg(elapsed_time), count(elapsed_time) from #{engine_name};" do |rs|
            rs.each do
              ary.push "#{engine_name} average elapsed_time: #{rs.read(Float64)} msecs for #{rs.read(Int64)} samples\n"
            end
          end
        end
        puts ary.sort_by { |e| e[/[\d\.]+/].to_f64 }.join
      end
    else
      DB.open DB_FILE do |db|
        engine_names.each do |engine_name|
          db.exec "create table if not exists #{engine_name} (
            id INTEGER PRIMARY KEY,
            elapsed_time INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );"
        end

        STDERR.puts "Initialize profile dbs done."
      end
    end
    exit
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

if !File.exists? DB_FILE.split(':')[1]
  STDERR.puts "Run `translater --profile' first."
  exit
end

Translater.new(
  content: content,
  target_language: target_language,
  debug_mode: debug_mode,
  browser: browser,
  engine_list: engine_list,
  timeout_seconds: timeout_seconds
)
