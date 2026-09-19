require "option_parser"
require "./translater"

def available_engines : Array(Engine)
  if File.exists? ENGINE_INIT_FILE
    File.read_lines(ENGINE_INIT_FILE).compact_map do |name|
      Engine.parse?(name.strip)
    end
  else
    STDERR.puts "Try run `translater --init' at first launch for a better use experince."
    Engine.values
  end
end

debug_mode = false
content = ""
browser = Browser::Firefox
engine_list = [] of Engine

timeout_seconds : Int32 = 10
engine_init = false

# FIXME: Don't know why, run spec on github action, cause #pipe? return true.
if STDIN.info.type.pipe?
  content = String.build do |io|
    while (input = STDIN.gets)
      io << input
    end
  end

  ARGV << "--help" if content.empty? # hack for github action.
else
  ARGV << "--help" if ARGV.empty?
end

begin
  OptionParser.parse do |parser|
    parser.banner = <<-USAGE
Usage: translater <option> content
USAGE

    # parser.on(
    #       "-b BROWSER",
    #       "--browser=BROWSER",
    #       "Specify browser used for scrap, support #{Browser.names.map(&.downcase).join(", ")}, default use Firefox.
    # Only Firefox can be guaranteed.
    # ") do |b|
    #       value = Browser.parse?(b)

    #       if value.nil?
    #         abort "Supported options: #{Browser.names.map(&.downcase).join ", "}"
    #       else
    #         browser = value
    #       end
    #     end

    parser.on(
      "--init", "Check engines if work, and disable it if not available.") do
      run_profile
      engine_list = Engine.values
      content = "hello world!"
      engine_init = true
    end

    parser.on(
      "-e ENGINE",
      "--engine=ENGINE",
      "Specify engines used for translate, support #{Engine.names.map(&.downcase).join(", ")}.
    multi-engine is possible, joined with comma, e.g. -e youdao,bing
    ") do |e|
      inputs = e.split(",")
      engine_list = [] of Engine

      inputs.each do |i|
        if (engine = Engine.parse?(i))
          engine_list << engine
        else
          abort "Supported options: #{Engine.names.map(&.downcase).join ", "}"
        end
      end
    end

    parser.on(
      "-s ENGINE",
      "--skip=ENGINE",
      "Specify engines which always skip for translate, support #{Engine.names.map(&.downcase).join(", ")}.
    multi-engine is possible, joined with comma, e.g. -s baidu,youdao
    ") do |e|
      inputs = e.split(",")
      allowed_engine_list = Engine.values

      inputs.each do |i|
        if (engine = Engine.parse?(i))
          allowed_engine_list.delete(engine)
        else
          abort "Supported options: #{Engine.names.map(&.downcase).join ", "}"
        end
      end

      abort "At least one engine must remain after --skip." if allowed_engine_list.empty?

      engine_list = [allowed_engine_list.sample]
    end

    parser.on(
      "-a",
      "--auto",
      "Prefer to use the fastest engine instead of select a random one, you need run --profile before this feature.") do
      if profile_db_exists?
        DB.connect PROFILE_DB_FILE do |db|
          db.query "select name from fastest_engine limit 1;" do |rs|
            rs.each do
              # If fastest_engine is empty, this block will be ignored.
              if (engine = Engine.parse(rs.read(String)))
                if available_engines.includes? engine
                  engine_list = [engine]
                else
                  STDERR.puts "The fastest engine is blocked by translater --init, selecting a random one."
                  engines = available_engines
                  engine_list = [engines.sample] if engines.present?
                end
              end
            end
          end
        end
      else
        STDERR.puts "No db exists, ignore --auto option."
      end
    end

    parser.on(
      "-A",
      "Use all known engine for translate, can be used for profile purpose.") do
      engine_list = available_engines
    end

    parser.on(
      "--timeout=SECONDS",
      "Specify timeout for get translate result, default is 10 seconds") do |seconds|
      parsed_seconds = seconds.to_i?
      abort "Timeout must be a positive integer." unless parsed_seconds && parsed_seconds > 0
      timeout_seconds = parsed_seconds
    end

    parser.unknown_args do |args|
      next if engine_init

      if !STDIN.info.type.pipe?
        if args.empty?
          STDOUT.puts "Please specify translate content. e.g. translater 'hello, China!'"
          exit 0
        else
          if args.first.blank?
            abort "Translate content must be present. e.g. translater 'hello, China!'"
          end

          content = args.first.strip
        end
      end
    end

    parser.on("-D", "--debug", "Debug mode, will disable browser headless mode, and pause for investigation.") do
      debug_mode = true
      timeout_seconds = 100000 # disable timeout if debug mode
    end

    parser.on("--profile", "Create profile dbs for translate engines.") do
      run_profile
      exit
    end

    parser.on("-h", "--help", "Show this help message and exit") do
      STDOUT.puts parser
      exit 0
    end

    parser.on("-v", "--version", "Show version") do
      STDOUT.puts Translater::VERSION
      exit 0
    end

    parser.invalid_option do |flag|
      STDERR.puts "Invalid option: #{flag}.\n\n"
      abort parser
    end

    parser.missing_option do |flag|
      STDERR.puts "Missing option for #{flag}\n\n"
      abort parser
    end
  end
rescue SQLite3::Exception
  STDERR.puts "Visit profile db file #{PROFILE_DB_FILE} failed, try delete it and retry."
end

def run_profile
  engine_names = Engine.names.map(&.downcase)

  if profile_db_exists?
    DB.connect PROFILE_DB_FILE do |db|
      ary = [] of String

      engine_names.each do |engine_name|
        db.query "select avg(elapsed_seconds), count(elapsed_seconds) from #{engine_name};" do |rs|
          rs.each do
            avg = rs.read(Float64?)
            count = rs.read(Int64)

            elapsed_seconds = if avg
                                sprintf("%.2f", avg)
                              else
                                "NA"
                              end

            ary.push "#{engine_name}: average spent #{elapsed_seconds} seconds for #{count} samples\n" if elapsed_seconds != "NA"
          end
        end
      end

      ary.sort_by! &.[/[\d\.]+/].to_f64

      if ary.empty?
        STDERR.puts "No profile samples exist yet. Run a translation or `translater --init` first."
        return
      end

      fastest_engine = ary[0][/(\w+):/, 1]

      db.exec("INSERT INTO fastest_engine (id,name) VALUES (?, ?) ON CONFLICT (id) DO UPDATE SET name = ?;", 1, fastest_engine, fastest_engine)

      puts ary.join
    end
  else
    DB.connect PROFILE_DB_FILE do |db|
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
end

if content =~ /\p{Han}/
  target_language = TargetLanguage::English
else
  target_language = TargetLanguage::Chinese
end

if engine_list.empty?
  engines = available_engines
  abort "No translation engine is currently available. Run `translater --init`." if engines.empty?
  engine_list = [engines.sample]
end

success = Translater.run(
  content: content,
  target_language: target_language,
  debug_mode: debug_mode,
  browser: browser,
  engine_list: engine_list,
  timeout_seconds: timeout_seconds,
  engine_init: engine_init
)

exit 1 unless success
