require "selenium"
require "./translater/**"

class Translater
  def ready?(driver)
    driver.status.ready?
  rescue Socket::ConnectError
    false
  end

  def create_driver(browser, debug_mode)
    user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0"

    case browser
    in Browser::Firefox
      driver_paths = ["/usr/local/bin/geckodriver", "/usr/bin/geckodriver"]

      driver_path = driver_paths.each do |path|
        break path if File.executable? path
      end

      if driver_path.nil?
        abort "#{driver_paths.join(" or ")} not exists! Please install correct version Selenium driver for Firefox before continue, exit ..."
      end

      service = Selenium::Service.firefox(driver_path: driver_path)
      driver = Selenium::Driver.for(:firefox, service: service)
      options = Selenium::Firefox::Capabilities::FirefoxOptions.new
      options.args = ["--headless"] unless debug_mode == true

      capabilities = Selenium::Firefox::Capabilities.new
      capabilities.firefox_options = options
    in Browser::Chrome
      driver = Selenium::Driver.for(:chrome, base_url: "http://localhost:9515")

      if !ready?(driver)
        driver_paths = ["/usr/local/bin/chromedriver", "/usr/bin/chromedriver"]

        driver_path = driver_paths.each do |path|
          break path if File.executable? path
        end

        if driver_path.nil?
          abort "#{driver_paths.join(" or ")} not exists! Please install correct version Selenium driver for Chrome before continue, exit ..."
        end

        service = Selenium::Service.chrome(driver_path: driver_path)

        driver = Selenium::Driver.for(:chrome, service: service)
      end

      options = Selenium::Chrome::Capabilities::ChromeOptions.new
      options.args = [
        "--headless=new",
        %{--user-agent="#{user_agent}"},
        "--use-mobile-user-agent",
      ] unless debug_mode == true

      capabilities = Selenium::Chrome::Capabilities.new
      capabilities.chrome_options = options
    end

    {driver, capabilities}
  rescue
    abort "Failed, please check browser driver.
If it still doesn't work, try delete files under ~/.webrivers and try again."
  end

  def create_session(driver, capabilities)
    new_session = driver.create_session(capabilities)

    # Clean Cookies 会造成某些网站检测浏览器使用自动控制软件.
    # cookie_manager = Selenium::CookieManager.new(command_handler: new_session.command_handler, session_id: new_session.id)
    # cookie_manager.delete_all_cookies

    new_session
  end

  def initialize(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    begin
      chan = Channel(Tuple(String, String, Time::Span)).new

      driver, capabilities = create_driver(browser, debug_mode).not_nil!

      start_time = Time.monotonic

      print "Using "

      if engine_list.includes? "Youdao"
        print "Youdao "
        spawn Youdao.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Tencent"
        print "Tencent "
        spawn Tencent.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Ali"
        print "Ali "
        spawn Ali.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Baidu"
        print "Baidu "
        spawn Baidu.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
      end

      if engine_list.includes? "Volc"
        print "Volc "
        spawn Volc.new(create_session(driver, capabilities), content, debug_mode, chan, start_time)
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
      STDERR.puts "Insert to table on #{DB_FILE} failed, try delete it and retry."
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
