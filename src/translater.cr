require "selenium"
require "set"
require "db"
require "sqlite3"
require "./translater/config"
require "./translater/selenium/*"
require "./translater/version"
require "./translater/ali"
require "./translater/bing"
require "./translater/baidu"
require "./translater/youdao"
# require "./translater/tencent"

enum TargetLanguage
  Chinese
  English
end

enum Browser
  Firefox
end

enum Engine
  Ali
  Baidu
  Bing
  Youdao
end

record EngineResult,
  engine : Engine,
  text : String?,
  elapsed : Time::Span,
  browser : Browser,
  cached : Bool,
  error : Exception? do
  def success? : Bool
    error.nil? && text.try { |value| !value.blank? } == true
  end
end

enum FirefoxStatus
  FirstRun
  Ready
  Started
end

class Translater
  property driver : Selenium::Driver
  property port : Int32
  getter engine : Engine

  def initialize(@engine : Engine, @debug_mode : Bool, target_language : TargetLanguage)
    @port = case @engine
            in .ali?
              4444
            in .baidu?
              4445
            in .bing?
              4446
              # in .tencent?
              #   4447
            in .youdao?
              4448
              # in .volc?
              # 4449
            end

    if target_language.english?
      @port += 100
    end

    @driver = Selenium::Driver.for(:firefox, base_url: "http://localhost:#{port}")
  end

  private def firefox_status : FirefoxStatus
    if driver.status.ready?
      FirefoxStatus::Ready
    else
      # WebDriver's `ready` field indicates whether it can accept a new
      # session. A responsive single-session geckodriver that is not ready
      # therefore already owns a session, regardless of its localized message.
      FirefoxStatus::Started
    end
  rescue Socket::ConnectError
    FirefoxStatus::FirstRun
  end

  private def create_and_cache_session_to(table_name, column_name) : Selenium::Session
    options = Selenium::Firefox::Capabilities::FirefoxOptions.new
    options.args = ["--headless"] unless @debug_mode == true
    capabilities = Selenium::Firefox::Capabilities.new
    capabilities.firefox_options = options

    session = driver.create_session(capabilities)
    serialized_session = session.to_json

    DB.open SESSION_DB_FILE do |db|
      db.exec "create table if not exists #{table_name} (
              id INTEGER PRIMARY KEY,
              #{column_name} TEXT
    );"

      db.exec(
        "INSERT INTO #{table_name} (id,#{column_name}) VALUES (?, ?) ON CONFLICT (id) DO UPDATE SET #{column_name} = ?;",
        port,
        serialized_session,
        serialized_session
      )
    end

    session
  end

  private def record_exists?(table_name, column_name, id) : String | Bool
    File.exists?(SESSION_DB_FILE.split(':')[1]) &&
      DB.connect SESSION_DB_FILE do |db|
        db.query_each "select #{column_name} from #{table_name} where id = #{id} limit 1;" do |rs|
          return rs.read(String)
        end
      end
    false
  rescue e : SQLite3::Exception
    e.inspect_with_backtrace(STDERR)
    false
  end

  def find_or_create_firefox_session : Tuple(Selenium::Session, Bool)
    table_name = "sessions"
    column_name = "json"

    status = self.firefox_status

    if status.first_run? || status.ready?
      # 两种情况都没有启动 Firefox, 因此, 清除老的 session
      if record_exists?(table_name, column_name, port)
        DB.connect(SESSION_DB_FILE) { |db| db.exec "delete from #{table_name} where id = #{port};" }
      end

      if status.first_run?
        # 此时 geckodriver 没有启动, 因此从 service 建立新的 driver
        driver_binary = "geckodriver"

        driver_paths = [
          "/usr/local/bin/#{driver_binary}",
          "/usr/bin/#{driver_binary}",
          Path["~/.webdrivers/#{driver_binary}"].expand(home: true),
        ]

        driver_path = driver_paths.each do |path|
          break path.to_s if File::Info.executable? path
        end

        if driver_path.nil?
          driver_path = Process.find_executable(driver_binary)

          if driver_path.nil?
            raise "Selenium driver couldn't be found on the path!
try install it into #{driver_paths.join(" or ")} before continue, exit ..."
          end
        end

        service = Selenium::Service.firefox(driver_path: driver_path, port: port)
        self.driver = Selenium::Driver.for(:firefox, service: service)
      end

      # 此时 geckodriver 已经启动, 是 ready? 状态, 建立新的 session, 并持久化
      # 注意: 直接使用 for 来创建 driver, 可能导致 driver.service 为 nil, 所以 port 作为参数传进去.
      # driver = Selenium::Driver.for(:firefox, base_url: "http://localhost:4444")
      # pp! driver.service.not_nil!.@port
      session = create_and_cache_session_to(table_name, column_name)
      is_new_session = true
    elsif status.started?
      serialized_session = record_exists?(table_name, column_name, port)

      if serialized_session
        # STDERR.puts "Using #{engine} cache"

        session = Selenium::Session.from_json(serialized_session.as(String))
        is_new_session = false
      else
        STDERR.puts "Try Terminating running driver(http://localhost:#{port}) because browser session is unavailable, but driver was started.
if still not work, kill the geckodriver process manually before try again."
        driver.stop
        raise "The running WebDriver has no reusable browser session."
      end
    end

    # 重新获取更新后的的状态
    if firefox_status.started?
      active_session = session.not_nil!
      configure_session(active_session)
      {active_session, is_new_session.not_nil!}
    else
      STDERR.puts "Try terminating running driver(http://localhost:#{port}) because #{driver.status.inspect}.
if still not work, kill the geckodriver process manually before try again."
      DB.connect(SESSION_DB_FILE) { |db| db.exec "delete from #{table_name} where id = #{port};" }
      session.delete if session
      driver.stop
      raise "WebDriver failed to start or recover a browser session."
    end
  end

  private def configure_session(session : Selenium::Session)
    session.set_timeouts Selenium::TimeoutConfiguration.new(
      script: 10_000,
      page_load: 15_000,
      implicit: 0
    )
    session.window_manager.set_window_rect(width: 1365_i64, height: 900_i64)
  end

  def input(element, content, wait_interval = 50.milliseconds)
    if content.size > 30
      content1 = content[0..-10]
      content2 = content[-9..-1]

      element.send_keys(key: content1)

      # 先粘贴，后手动输入，间隔时间不能太长。
      # 否则可能会造成 ali 的引擎，将后面手动输入的部分忽略
      sleep 100.milliseconds

      content2.each_char do |e|
        element.send_keys(key: e.to_s)
        sleep wait_interval
      end
    else
      content.each_char do |e|
        element.send_keys(key: e.to_s)
        sleep wait_interval
      end
    end
  end

  def self.run(content, target_language, debug_mode, browser, engine_list, timeout_seconds, engine_init) : Bool
    return true if content == "--help"

    engines = engine_list.uniq
    return false if engines.empty?

    begin
      chan = Channel(EngineResult).new(engines.size)

      start_time = Time.instant

      print "Using "

      if engines.includes? Engine::Ali
        print "Ali "
        spawn_engine(Engine::Ali, browser, content, debug_mode, chan, start_time, target_language)
      end

      if engines.includes? Engine::Baidu
        print "Baidu "
        spawn_engine(Engine::Baidu, browser, content, debug_mode, chan, start_time, target_language)
      end

      if engines.includes? Engine::Bing
        print "Bing "
        spawn_engine(Engine::Bing, browser, content, debug_mode, chan, start_time, target_language)
      end

      # if engine_list.includes? "Tencent"
      #   print "Tencent "
      #   spawn Tencent.new(browser, content, debug_mode, chan, start_time, target_language)
      # end

      # if engine_list.includes? "Volc"
      #   print "Volc "
      #   spawn Volc.new(browser, content, debug_mode, chan, start_time, target_language)
      # end

      if engines.includes? Engine::Youdao
        print "Youdao "
        spawn_engine(Engine::Youdao, browser, content, debug_mode, chan, start_time, target_language)
      end

      puts

      begin
        # 这里从 connect 改为 open, 允许创建一个连接池, 进而允许多个连接同时执行.
        # 否则, 添加多引擎时, 会报错.
        db = DB.open(PROFILE_DB_FILE) if profile_db_exists?

        # 代表已经运行过 engine_init
        file = File.open(ENGINE_INIT_FILE, mode: "w") if engine_init

        pending_engines = engines.to_set
        success_count = 0
        deadline = Time.instant + timeout_seconds.seconds

        while pending_engines.present?
          remaining = deadline - Time.instant
          break if remaining <= Time::Span.zero

          received_result = select
          when engine_result = chan.receive
            engine_result
          when timeout remaining
            nil
          end

          break unless received_result

          pending_engines.delete(received_result.engine)

          if received_result.success?
            translated_text = received_result.text.not_nil!
            engine_name = received_result.engine.to_s
            elapsed_seconds = sprintf("%.2f", received_result.elapsed.total_seconds)

            if db
              begin
                db.exec "insert into #{engine_name.underscore} (elapsed_seconds) values (?)", elapsed_seconds.to_f
              rescue error : SQLite3::Exception
                STDERR.puts "Could not update #{PROFILE_DB_FILE}: #{error.message}"
              end
            end

            file.puts engine_name if file
            success_count += 1

            puts "---------- #{engine_name}, spent #{elapsed_seconds} seconds use #{received_result.browser}#{received_result.cached ? " cache" : ""} ----------\n#{translated_text}"
          else
            message = received_result.error.try(&.message) || "returned an empty translation"
            STDERR.puts "#{received_result.engine} failed: #{message}"
          end
        end

        if pending_engines.present?
          STDERR.puts "Timed out after #{timeout_seconds} seconds waiting for: #{pending_engines.join(", ")}"
        end

        success_count > 0
      ensure
        db.close if db
        file.close if file
      end
    rescue e
      e.inspect_with_backtrace(STDERR)
      false
    end
  end

  private def self.spawn_engine(engine, browser, content, debug_mode, chan, start_time, target_language)
    spawn(name: "translater-#{engine.to_s.downcase}") do
      case engine
      in .ali?
        Ali.new(browser, content, debug_mode, chan, start_time, target_language)
      in .baidu?
        Baidu.new(browser, content, debug_mode, chan, start_time, target_language)
      in .bing?
        Bing.new(browser, content, debug_mode, chan, start_time, target_language)
      in .youdao?
        Youdao.new(browser, content, debug_mode, chan, start_time, target_language)
      end
    rescue error
      chan.send EngineResult.new(
        engine: engine,
        text: nil,
        elapsed: Time.instant - start_time,
        browser: browser,
        cached: false,
        error: error
      )
    end
  end
end
