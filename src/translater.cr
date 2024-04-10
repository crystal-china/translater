require "selenium"
require "./translater/**"

enum FirefoxStatus
  FirstRun
  Ready
  Started
  Unknown
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
            in .tencent?
              4447
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

  private def chrome_ready?(driver)
    driver.status.ready?
  rescue Socket::ConnectError
    false
  end

  private def firefox_status : FirefoxStatus
    if driver.status.message == "Session already started"
      FirefoxStatus::Started
    elsif driver.status.ready?
      FirefoxStatus::Ready
    else
      FirefoxStatus::Unknown
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

        driver_paths = ["/usr/local/bin/#{driver_binary}", "/usr/bin/#{driver_binary}"]

        driver_path = driver_paths.each do |path|
          break path if File.executable? path
        end

        if driver_path.nil?
          abort "#{driver_paths.join(" or ")} not exists! Please install correct version Selenium driver before continue, exit ..."
        end

        service = Selenium::Service.firefox(driver_path: "/usr/bin/geckodriver", port: port)
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
        exit 1
      end
    end

    # 重新获取更新后的的状态
    if firefox_status.started?
      {session.not_nil!, is_new_session.not_nil!}
    else
      STDERR.puts "Try terminating running driver(http://localhost:#{port}) because #{driver.status.inspect}.
if still not work, kill the geckodriver process manually before try again."
      DB.connect(SESSION_DB_FILE) { |db| db.exec "delete from #{table_name} where id = #{port};" }
      session.delete if session
      driver.stop
      exit 1
    end
  end

  def input_use_js(session, selector, content)
    document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)
    document_manager.execute_script(%{select = document.querySelector("#{selector}"); select.value = `#{content}`.trim()})
  end

  def input(element, content, wait_seconds = 0.05)
    if content.size > 30
      content1 = content[0..-10]
      content2 = content[-9..-1]

      element.send_keys(key: content1)

      # 先粘贴，后手动输入，间隔时间不能太长。
      # 否则可能会造成 ali 的引擎，将后面手动输入的部分忽略
      sleep 0.1

      content2.each_char do |e|
        element.send_keys(key: e.to_s)
        sleep wait_seconds
      end
    else
      content.each_char do |e|
        element.send_keys(key: e.to_s)
        sleep wait_seconds
      end
    end
  end

  def self.run(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    begin
      chan = Channel(Tuple(String, String, Time::Span, Browser, Bool)).new

      start_time = Time.monotonic

      if engine_list.includes? "Ali"
        print "Ali "
        spawn Ali.new(browser, content, debug_mode, chan, start_time, target_language)
      end

      if engine_list.includes? "Baidu"
        print "Baidu "
        spawn Baidu.new(browser, content, debug_mode, chan, start_time, target_language)
      end

      if engine_list.includes? "Bing"
        print "Bing "
        spawn Bing.new(browser, content, debug_mode, chan, start_time, target_language)
      end

      if engine_list.includes? "Tencent"
        print "Tencent "
        spawn Tencent.new(browser, content, debug_mode, chan, start_time, target_language)
      end

      # if engine_list.includes? "Volc"
      #   print "Volc "
      #   spawn Volc.new(browser, content, debug_mode, chan, start_time, target_language)
      # end

      if engine_list.includes? "Youdao"
        print "Youdao "
        spawn Youdao.new(browser, content, debug_mode, chan, start_time, target_language)
      end

      puts

      begin
        db = DB.connect(PROFILE_DB_FILE) if profile_db_exists?

        engine_list.size.times do
          select
          when result = chan.receive
            translated_text, engine_name, time_span, browser, is_new_session = result
            elapsed_seconds = sprintf("%.2f", time_span.total_seconds)
            table_name = engine_name.underscore

            db.exec "insert into #{table_name} (elapsed_seconds) values (?)", elapsed_seconds.to_f if db

            puts "---------- #{engine_name}, spent #{elapsed_seconds} seconds use #{browser}#{is_new_session ? "" : " cache"} ----------\n#{translated_text}"
          when timeout timeout_seconds.seconds
            STDERR.puts "Timeout for #{timeout_seconds} seconds!"
          end
        rescue SQLite3::Exception
          STDERR.puts "Visit table #{table_name} in db file #{PROFILE_DB_FILE} failed, try delete db file and retry."
        ensure
          db.close if db
        end
      end
    rescue e
      e.inspect_with_backtrace(STDERR)
    end
  end
end
