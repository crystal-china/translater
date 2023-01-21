require "option_parser"
require "selenium"
require "webdrivers"
require "./translater/*"

enum Engine
  # Bing
  Youdao
  Tencent
  Ali
  Baidu
end

enum TargetLanguage
  Chinese
  English
end

enum Browser
  Firefox
end

module Translater
  target_language : TargetLanguage? = nil
  debug_mode = false
  content = ""
  browser = Browser::Firefox
  engine_list = Engine.values.shuffle![0..0]
  timeout_seconds : Int32 = 10

  stdin = [] of String

  if STDIN.info.type.pipe?
    while (input = STDIN.gets)
      stdin << input
    end
    content = stdin.join("\n").strip
  else
    ARGV << "--help" if ARGV.empty?
  end

  OptionParser.parse do |parser|
    parser.banner = <<-USAGE
Usage: translater <option> content
USAGE

    # parser.on(
    #       "-t TARGET",
    #       "--target=TARGET",
    #       "Specify target language, support zh-CN|en for now.
    # default is translate English to Chinese.
    # Youdao don't support this option.
    # "
    #     ) do |target|
    #       target_language = TargetLanguage.parse?(target)

    #       if target_language.nil?
    #         STDERR.puts "Supported options: #{TargetLanguage.names.map(&.downcase).join ", "}"
    #         exit 1
    #       end
    #     end

    parser.on(
      "-b BROWSER",
      "--browser=BROWSER",
      "Specify browser used for scrap, only support firefox for now, default is firefox.
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
      "Specify engine used for translate, support youdao,tencent,ali,baidu,bing.
multi-engine is supported, split with comma, e.g. -e youdao,tencent
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
      "--timeout=SECONDS",
      "Specify timeout for get translate result, default is 10 seconds") do |seconds|
      timeout_seconds = seconds.to_i
    end

    parser.unknown_args do |args|
      if !STDIN.info.type.pipe?
        if args.empty?
          STDERR.puts "Please specify translate content. e.g. translater 'hello, China!'"
          exit
        else
          if args.first.blank?
            STDERR.puts "Translate content must be present. e.g. translater 'hello, China!'"
            exit
          end

          content = args.first.strip
        end
      end
    end

    parser.on("-D", "--debug", "Debug mode") do
      debug_mode = true
      timeout_seconds = 100000 # disable timeout if debug mode
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

  if content != "--help"
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
          youdao_translater(session, content, debug_mode) if engine_list.includes? Engine::Youdao
          tencent_translater(session, content, debug_mode) if engine_list.includes? Engine::Tencent
          alibaba_translater(session, content, debug_mode) if engine_list.includes? Engine::Ali
          baidu_translater(session, content, debug_mode) if engine_list.includes? Engine::Baidu

          chan.send(nil)
          # rescue e : Selenium::Error
          #   STDERR.puts e.message
          #   exit
end
      end

      select
      when chan.receive
      when timeout (engine_list.size * timeout_seconds).seconds
        STDERR.puts %{Timeout! engine: #{engine_list.join(", ")}}
      end
    end
  end

  def self.youdao_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.youdao.com/index.html")

    until (source_content_ele = session.find_by_selector("#js_fanyi_input"))
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    input(source_content_ele, content)

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    until result = session.find_by_selector("#js_fanyi_output_resultOutput")
      sleep 0.2
    end

    while result.text.blank?
      sleep 0.2
    end

    puts "---------------Youdao---------------\n#{result.text}"
  end

  def self.tencent_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.qq.com/")

    until (source_content_ele = session.find_by_selector(".textpanel-source.active .textpanel-source-textarea textarea.textinput"))
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    input(source_content_ele, content)

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    until result = session.find_by_selector(".textpanel-target-textblock")
      sleep 0.2
    end

    while result.text.blank?
      sleep 0.2
    end

    puts "---------------Tencent---------------\n#{result.text}"
  end

  def self.alibaba_translater(session, content, debug_mode)
    session.navigate_to("https://translate.alibaba.com/")

    until (source_content_ele = session.find_by_selector("textarea#source"))
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    input(source_content_ele, content)

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    until result = session.find_by_selector("pre#pre")
      sleep 0.2
    end

    while result.text.blank?
      sleep 0.2
    end

    puts "---------------Alibaba---------------\n#{result.text}"
  end

  def self.baidu_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.baidu.com/")

    while session.find_by_selector "#app-guide"
      while (element = session.find_by_selector "span.app-guide-close")
        element.click

        sleep 0.2
      end

      break if session.find_by_selector ".app-guide-hide"

      sleep 0.2
    end

    until (source_content_ele = session.find_by_selector("textarea#baidu_translate_input"))
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    input(source_content_ele, content)

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    until result = session.find_by_selector("p.ordinary-output.target-output")
      sleep 0.2
    end

    while result.text.blank?
      sleep 0.2
    end

    puts "---------------Baidu---------------\n#{result.text}"
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

  at_exit do
    session.delete unless session.nil?
    driver.stop unless driver.nil?
  end
end
