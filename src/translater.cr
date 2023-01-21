require "webdrivers"
require "selenium"
require "./translater/**"

class Translater
  def initialize(content, target_language, debug_mode, browser, engine_list, timeout_seconds)
    return if content == "--help"

    begin
      case browser
      in Browser::Firefox
        if Webdrivers::Geckodriver.driver_version
          driver_path = Webdrivers::Geckodriver.driver_path
        else
          driver_path = Webdrivers::Geckodriver.install
        end

        service = Selenium::Service.firefox(driver_path: File.expand_path(driver_path, home: true))
        driver = Selenium::Driver.for(:firefox, service: service)
        options = Selenium::Firefox::Capabilities::FirefoxOptions.new
        options.args = ["--headless"] unless debug_mode == true

        capabilities = Selenium::Firefox::Capabilities.new
        capabilities.firefox_options = options
        # when "chrome"
        #   if Webdrivers::Chromedriver.driver_version
        #     driver_path = Webdrivers::Chromedriver.driver_path
        #   else
        #     driver_path = Webdrivers::Chromedriver.install
        #   end

        #   service = Selenium::Service.chrome(driver_path: File.expand_path(driver_path, home: true))
        #   driver = Selenium::Driver.for(:chrome, service: service)

        #   options = Selenium::Chrome::Capabilities::ChromeOptions.new
        #   options.args = ["headless"] unless debug_mode == true

        #   capabilities = Selenium::Chrome::Capabilities.new
        #   capabilities.chrome_options = options
        # else
        #   STDERR.puts "Only support firefox for now, firefox is default."
        #   exit
      end

      session = driver.create_session(capabilities)

      # Clean Cookies
      cookie_manager = Selenium::CookieManager.new(command_handler: session.command_handler, session_id: session.id)
      cookie_manager.delete_all_cookies

      chan = Channel(Nil).new

      spawn do
        begin
          Youdao.new(session, content, debug_mode) if engine_list.includes? Engine::Youdao
          Tencent.new(session, content, debug_mode) if engine_list.includes? Engine::Tencent
          Ali.new(session, content, debug_mode) if engine_list.includes? Engine::Ali
          Baidu.new(session, content, debug_mode) if engine_list.includes? Engine::Baidu

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
      end
    end
  ensure
    session.delete unless session.nil?
    driver.stop unless driver.nil?
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
