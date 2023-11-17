require "selenium"
require "./translater/**"

class Translater
  def create_driver(browser, debug_mode)
    case browser
    in Browser::Firefox
      driver_path = File.expand_path("~/.webdrivers/geckodriver", home: true)
      if !File.exists?(driver_path)
        STDERR.puts "#{driver_path} not exists! Please install correct version selenium driver for Firefox manually before continue, exit ..."
        exit
      end
      service = Selenium::Service.firefox(driver_path: driver_path)
      driver = Selenium::Driver.for(:firefox, service: service)
      options = Selenium::Firefox::Capabilities::FirefoxOptions.new
      options.args = ["--headless"] unless debug_mode == true

      capabilities = Selenium::Firefox::Capabilities.new
      capabilities.firefox_options = options
    in Browser::Chrome
      driver_path = File.expand_path("~/.webdrivers/chromedriver", home: true)
      if !File.exists?(driver_path)
        STDERR.puts "#{driver_path} not exists! Please install correct version selenium driver for Chrome manually before continue, exit ..."
        exit
      end
      service = Selenium::Service.chrome(driver_path: driver_path)
      driver = Selenium::Driver.for(:chrome, service: service)
      options = Selenium::Chrome::Capabilities::ChromeOptions.new
      options.args = ["--headless"] unless debug_mode == true

      capabilities = Selenium::Chrome::Capabilities.new
      capabilities.chrome_options = options
    end

    {driver, capabilities}
  rescue
    STDERR.puts "Failed, please check browser driver.
If it still doesn't work, try delete files under ~/.webrivers and try again."
  end

  def create_session(driver, capabilities)
    new_session = driver.create_session(capabilities)
    # if driver.status.ready?

    # else
    #   session = nil
    # end

    # new_session = session.not_nil!

    # Clean Cookies
    cookie_manager = Selenium::CookieManager.new(command_handler: new_session.command_handler, session_id: new_session.id)
    cookie_manager.delete_all_cookies

    new_session
  end

  def initialize(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    begin
      chan = Channel(Tuple(String, String, Time::Span)).new

      driver, capabilities = create_driver(browser, debug_mode).not_nil!

      start_time = Time.monotonic

      print "Using "

      if engine_list.includes? Engine::Youdao
        print "Youdao "
        spawn Youdao.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? Engine::Tencent
        print "Tencent "
        spawn Tencent.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? Engine::Ali
        print "Ali "
        spawn Ali.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? Engine::Baidu
        print "Baidu "
        spawn Baidu.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      puts

      DB.open DB_FILE do |db|
        engine_list.size.times do
          select
          when result = chan.receive
            translated_text, engine_name, time_span = result
            elapsed_seconds = sprintf("%.2f", time_span.total_seconds)

            puts "---------------#{engine_name}, spent #{elapsed_seconds} seconds---------------\n#{translated_text}"
            db.exec "insert into #{engine_name.underscore} (elapsed_seconds) values (?)", elapsed_seconds.to_f
          when timeout timeout_seconds.seconds
            STDERR.puts "Timeout!"
          end
        end
      end
    rescue SQLite3::Exception
    rescue e
      e.inspect_with_backtrace(STDERR)
    ensure
      sleep 0.05
      driver.stop if driver
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
