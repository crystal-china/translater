require "selenium"
require "./driver"
require "./translater/**"

class Translater
  def self.ready?(driver)
    driver.status.ready?
  rescue Socket::ConnectError
    false
  end

  def self.create_driver(browser, debug_mode)
    case browser
    in Browser::Firefox
      driver = Translater::Driver.for(:firefox, base_url: "http://localhost:4444")

      options = Selenium::Firefox::Capabilities::FirefoxOptions.new
      options.args = [
        "--headless",
      ] unless debug_mode == true

      capabilities = Selenium::Firefox::Capabilities.new
      capabilities.firefox_options = options
    in Browser::Chrome
      driver = Translater::Driver.for(:chrome, base_url: "http://localhost:9515")

      options = Selenium::Chrome::Capabilities::ChromeOptions.new
      options.args = [
        "--headless=new",
        "--no-sandbox",
      ] unless debug_mode == true

      capabilities = Selenium::Chrome::Capabilities.new
      capabilities.chrome_options = options
    end

    session = driver.create_session(capabilities)

    # Clean Cookies 会造成某些网站检测浏览器使用自动控制软件.
    # cookie_manager = Selenium::CookieManager.new(command_handler: session.command_handler, session_id: session.id)
    # cookie_manager.delete_all_cookies

    {session, driver}
  rescue e
    e.inspect_with_backtrace(STDERR)
    STDERR.puts "Failed, please check browser driver.
If it still doesn't work, try delete files under ~/.webrivers and try again."

    session.delete if session
    # driver.stop if driver

    exit(1)
  end

  def initialize(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    begin
      chan = Channel(Tuple(String, String, Time::Span, Browser)).new

      start_time = Time.monotonic

      print "Using "

      if engine_list.includes? "Youdao"
        print "Youdao "
        spawn Youdao.new(browser, content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Tencent"
        print "Tencent "
        spawn Tencent.new(Browser::Firefox, content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Ali"
        print "Ali "
        spawn Ali.new(browser, content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Baidu"
        print "Baidu "
        spawn Baidu.new(Browser::Chrome, content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Volc"
        print "Volc "
        spawn Volc.new(browser, content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Bing"
        print "Bing "
        spawn Bing.new(Browser::Firefox, content, debug_mode, chan, start_time)
      end

      puts

      begin
        db = DB.open(DB_FILE) if db_exists?

        engine_list.size.times do
          select
          when result = chan.receive
            translated_text, engine_name, time_span, browser = result
            elapsed_seconds = sprintf("%.2f", time_span.total_seconds)

            puts "---------------#{engine_name} use #{browser}, spent #{elapsed_seconds} seconds---------------\n#{translated_text}"
            db.exec "insert into #{engine_name.underscore} (elapsed_seconds) values (?)", elapsed_seconds.to_f if db
          when timeout timeout_seconds.seconds
            STDERR.puts "Timeout!"
          end
        ensure
          db.close if db
        end
      end
    rescue SQLite3::Exception
      STDERR.puts "Visit db file #{DB_FILE} failed, try delete it and retry."
    rescue e
      e.inspect_with_backtrace(STDERR)
    end
  end

  def self.input_use_js(session, selector, content)
    document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)
    document_manager.execute_script(%{select = document.querySelector("#{selector}"); select.value = `#{content}`.trim()})
  end

  def self.input(element, content, wait_seconds = 0.05)
    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      element.send_keys(key: content1)

      sleep wait_seconds

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
end
