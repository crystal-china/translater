require "option_parser"
require "./translater"
require "db"
require "sqlite3"

DB_FILE_NAME         = "profile.db"
DB_DEFAULT_FILE_PATH = Path["~/.#{DB_FILE_NAME}"].expand(home: true)

def find_db_path
  db_file_path = (Path["#{Process.executable_path.as(String)}/../.."] / DB_FILE_NAME).expand

  return db_file_path if File.exists?(db_file_path)

  xdg_data_home = ENV.fetch("XDG_DATA_HOME", "~/.local/share")

  db_file_paths = {
    Path[xdg_data_home] / "translater" / DB_FILE_NAME,
  }

  db_file_paths.each do |path|
    expanded_path = path.expand(home: true)
    return expanded_path if File.exists?(expanded_path)
  end

  DB_DEFAULT_FILE_PATH
end

DB_FILE = "sqlite3:#{find_db_path}"

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

# FIXME: Don't know why, run spec on github action, cause #pipe? return true.
if STDIN.info.type.pipe?
  while (input = STDIN.gets)
    stdin << input
  end
  content = stdin.join("\n").strip

  ARGV << "--help" if content.empty? # hack for github action.
else
  ARGV << "--help" if ARGV.empty?
end

OptionParser.parse do |parser|
  parser.banner = <<-USAGE
Usage: translater <option> content
USAGE

  parser.on(
    "-b BROWSER",
    "--browser=BROWSER",
    "Specify browser used for scrap, support Firefox and Chrome, default is Chrome.
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
    "-a",
    "--auto",
    "Use the fastest engine instead random selection, check --profile for details.") do
    DB.connect DB_FILE do |db|
      db.query "select name from fastest_engine limit 1;" do |rs|
        rs.each do
          # If fastest_engine is empty, this block will be ignored.
          engine_list = [Engine.parse(rs.read(String))]
        end
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
        exit 1
      else
        if args.first.blank?
          STDERR.puts "Translate content must be present. e.g. translater 'hello, China!'"
          exit 1
        end

        content = args.first.strip
      end
    end
  end

  parser.on("-D", "--debug", "Debug mode, will disable browser headless mode, and pause for investigation.") do
    debug_mode = true
    timeout_seconds = 100000 # disable timeout if debug mode
  end

  parser.on("--profile", "Create profile dbs for translate engines, you need run this once before use translater.") do
    engine_names = Engine.names.map(&.downcase)
    if File.exists? DB_FILE.split(':')[1]
      DB.connect DB_FILE do |db|
        ary = [] of String

        engine_names.each do |engine_name|
          db.query "select avg(elapsed_seconds), count(elapsed_seconds) from #{engine_name};" do |rs|
            rs.each do
              elapsed_seconds = sprintf("%.2f", rs.read(Float64))
              ary.push "#{engine_name}: average spent #{elapsed_seconds} seconds for #{rs.read(Int64)} samples\n"
            end
          end
        end

        ary.sort_by! &.[/[\d\.]+/].to_f64

        fastest_engine = ary[0][/(\w+):/, 1]

        db.exec("INSERT INTO fastest_engine (id,name) VALUES (?, ?) ON CONFLICT (id) DO UPDATE SET name = ?;", 1, fastest_engine, fastest_engine)

        puts ary.join
      end
    else
      DB.open DB_FILE do |db|
        engine_names.each do |engine_name|
          db.exec "create table if not exists #{engine_name} (
            id INTEGER PRIMARY KEY,
            elapsed_seconds REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );"
        end

        db.exec "create table if not exists fastest_engine (
            id INTEGER PRIMARY KEY,
            name TEXT
  );"

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

if !File.exists?(DB_FILE.split(':')[1]) && debug_mode == false
  STDERR.puts "Run `translater --profile' first."
  exit 1
end

Translater.new(
  content: content,
  target_language: target_language,
  debug_mode: debug_mode,
  browser: browser,
  engine_list: engine_list,
  timeout_seconds: timeout_seconds
)
