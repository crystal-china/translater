require "webdrivers"
require "selenium"
require "./translater/**"

class Translater
  def create_session(browser, debug_mode)
    case browser
    in Browser::Firefox
      driver_path = Webdrivers::Geckodriver.install
      # if Webdrivers::Geckodriver.driver_version
      #   driver_path = Webdrivers::Geckodriver.driver_path
      # else
      #   driver_path = Webdrivers::Geckodriver.install
      # end

      service = Selenium::Service.firefox(driver_path: File.expand_path(driver_path, home: true))
      driver = Selenium::Driver.for(:firefox, service: service)
      options = Selenium::Firefox::Capabilities::FirefoxOptions.new
      options.args = ["--headless"] unless debug_mode == true

      capabilities = Selenium::Firefox::Capabilities.new
      capabilities.firefox_options = options
    in Browser::Chrome
      driver_path = Webdrivers::Chromedriver.install
      # if Webdrivers::Chromedriver.driver_version
      #   driver_path = Webdrivers::Chromedriver.driver_path
      # else
      #   driver_path = Webdrivers::Chromedriver.install
      # end

      service = Selenium::Service.chrome(driver_path: File.expand_path(driver_path, home: true))
      driver = Selenium::Driver.for(:chrome, service: service)
      options = Selenium::Chrome::Capabilities::ChromeOptions.new
      options.args = ["--headless"] unless debug_mode == true

      capabilities = Selenium::Chrome::Capabilities.new
      capabilities.chrome_options = options
    end

    if driver.status.ready?
      session = driver.create_session(capabilities)
    else
      session = nil
    end

    new_session = session.not_nil!

    # Clean Cookies
    cookie_manager = Selenium::CookieManager.new(command_handler: new_session.command_handler, session_id: new_session.id)
    cookie_manager.delete_all_cookies

    new_session
  end

  def initialize(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    begin
      chan = Channel(Tuple(String, String, Time::Span)).new

      begin
        start_time = Time.monotonic

        if engine_list.includes? Engine::Youdao
          spawn Youdao.new(create_session(browser, debug_mode), content, debug_mode, chan, start_time)
        end

        if engine_list.includes? Engine::Tencent
          spawn Tencent.new(create_session(browser, debug_mode), content, debug_mode, chan, start_time)
        end

        if engine_list.includes? Engine::Ali
          spawn Ali.new(create_session(browser, debug_mode), content, debug_mode, chan, start_time)
        end

        if engine_list.includes? Engine::Baidu
          spawn Baidu.new(create_session(browser, debug_mode), content, debug_mode, chan, start_time)
        end
      rescue e : Selenium::Error
        STDERR.puts e.message
        exit
      end

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
    end
  end

  def self.input(element, content)
    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      element.send_keys(key: content1)
      content2.each_char do |e|
        element.send_keys(key: e.to_s)
        sleep 0.05
      end
    else
      content.each_char do |e|
        element.send_keys(key: e.to_s)
        sleep 0.05
      end
    end
  end
end
