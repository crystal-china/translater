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

    {driver, session}
  end

  def initialize(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    driver, session = create_session(browser, debug_mode)

    # while session.nil?
    #   STDERR.puts "Try restart current geckodriver ..."
    #   system("pkill geckodriver")
    #   sleep 1
    #   driver, session = create_session(browser, debug_mode)
    # end

    new_session = session.not_nil!

    begin
      # Clean Cookies
      cookie_manager = Selenium::CookieManager.new(command_handler: new_session.command_handler, session_id: new_session.id)
      cookie_manager.delete_all_cookies

      chan = Channel(Nil).new

      spawn do
        begin
          DB.connect DB_FILE do |db|
            start = Time.monotonic

            if engine_list.includes? Engine::Youdao
              Youdao.new(new_session, content, debug_mode)
              db.exec "insert into youdao (elapsed_time) values (?)", (Time.monotonic - start).milliseconds
            end

            if engine_list.includes? Engine::Tencent
              Tencent.new(new_session, content, debug_mode)
              db.exec "insert into tencent (elapsed_time) values (?)", (Time.monotonic - start).milliseconds
            end

            if engine_list.includes? Engine::Ali
              Ali.new(new_session, content, debug_mode)
              db.exec "insert into ali (elapsed_time) values (?)", (Time.monotonic - start).milliseconds
            end

            if engine_list.includes? Engine::Baidu
              Baidu.new(new_session, content, debug_mode)
              db.exec "insert into baidu (elapsed_time) values (?)", (Time.monotonic - start).milliseconds
            end
          end

          chan.send(nil)
        rescue e : Selenium::Error
          STDERR.puts e.message
          exit
        end
      end

      select
      when chan.receive
      when timeout (engine_list.size * timeout_seconds).seconds
        STDERR.puts %{Timeout! engine: #{engine_list.join(", ")}}
        if engine_list.size == 1
          DB.connect DB_FILE do |db|
            db.exec "insert into #{engine_list.first.to_s.downcase} (elapsed_time) values (?)", timeout_seconds * 1000
          end
        end
      end
    ensure
      new_session.delete
      driver.stop
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
