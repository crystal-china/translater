require "option_parser"
require "selenium"
require "webdrivers"
require "./bing_translater/*"

module BingTranslater
  target_language : String? = nil
  debug_mode = false
  content = ""
  browser = "firefox"
  engine = "youdao"

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
Usage: bing_translater <option> content
USAGE

    parser.on(
      "-t TARGET",
      "--target=TARGET",
      "Specify target language, support zh-CN|en for now.
default is translate English to Chinese.
Youdao don't support this option.
"
    ) do |target|
      case target
      when "zh-CN"
        target_language = "Chinese"
      when "en"
        target_language = "English"
      else
        STDERR.puts "Supported options: -t zh-CN|en"
        exit
      end
    end

    parser.on(
      "-b BROWSER",
      "--browser=BROWSER",
      "Specify browser used for scrap, only support firefox for now, default is firefox.
") do |b|
      case b.downcase
      when "firefox"
        browser = "firefox"
      else
        STDERR.puts "Supported options: -b firefox"
        exit
      end
    end

    parser.on(
      "-e ENGINE",
      "--engine=ENGINE",
      "Specify engine used for translate, support bing|youdao|tencent for now.
") do |e|
      case e.downcase
      when "bing"
        engine = "bing"
      when "youdao"
        engine = "youdao"
      when "tencent"
        engine = "tencent"
      when "alibaba"
        engine = "alibaba"
      else
        STDERR.puts "Supported options: -e bing|youado|tencent|alibaba"
        exit
      end
    end

    parser.unknown_args do |args|
      if args.empty?
        STDERR.puts "Please specify translate content. e.g. bing_translater 'hello, China!'"
        exit
      else
        if args.first.blank?
          STDERR.puts "Translate content must be present. e.g. bing_translater 'hello, China!'"
          exit
        end

        content = args.first.strip
      end
    end

    parser.on("-D", "--debug", "Debug mode") do
      debug_mode = true
    end

    parser.on("-h", "--help", "Show this help message and exit") do
      STDERR.puts parser
      exit
    end

    parser.on("-v", "--version", "Show version") do
      STDERR.puts BingTranslater::VERSION
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
      target_language = "English"
    else
      target_language = "Chinese"
    end
  end

  if content != "--help"
    begin
      case browser
      when "firefox"
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
      when "chrome"
        if Webdrivers::Chromedriver.driver_version
          driver_path = Webdrivers::Chromedriver.driver_path
        else
          driver_path = Webdrivers::Chromedriver.install
        end

        service = Selenium::Service.chrome(driver_path: File.expand_path(driver_path, home: true))
        driver = Selenium::Driver.for(:chrome, service: service)

        options = Selenium::Chrome::Capabilities::ChromeOptions.new
        options.args = ["headless"] unless debug_mode == true

        capabilities = Selenium::Chrome::Capabilities.new
        capabilities.chrome_options = options
      else
        STDERR.puts "Only support firefox for now, firefox is default."
        exit
      end

      session = driver.create_session(capabilities)

      # Clean Cookies
      cookie_manager = Selenium::CookieManager.new(command_handler: session.command_handler, session_id: session.id)
      cookie_manager.delete_all_cookies

      BingTranslater.bing_translater(session, content, debug_mode, target_language) if engine == "bing"
      BingTranslater.youdao_translater(session, content, debug_mode) if engine == "youdao"
      BingTranslater.tencent_translater(session, content, debug_mode) if engine == "tencent"
      BingTranslater.alibaba_translater(session, content, debug_mode) if engine == "alibaba"
    rescue e : Selenium::Error
      STDERR.puts e.message
      exit
    end
  end

  def self.bing_translater(session, content, debug_mode, target_language)
    session.navigate_to("https://www.bing.com/translator")

    while session.find_elements(:css, "select#tta_tgtsl optgroup#t_tgtRecentLang option").empty?
      sleep 0.2
    end

    source_content_ele = session.find_element(:css, "textarea#tta_input_ta")

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    end

    document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

    case target_language
    when "English"
      document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "en"})
    when "Chinese"
      document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "zh-Hans"})
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    result = ""

    loop do
      result = document_manager.execute_script(%{return document.querySelector("textarea#tta_output_ta").value})

      break unless result.strip == "..."

      sleep 0.1
    end

    puts "---------------Bing---------------\n#{result}"
  end

  def self.youdao_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.youdao.com/index.html")

    while (elements = session.find_elements(:css, "#js_fanyi_input"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    result = [] of Selenium::Element

    loop do
      result = session.find_elements(:css, "#js_fanyi_output_resultOutput")

      break unless result.empty?

      sleep 1
    end

    puts "---------------Youdao---------------\n#{result.first.text}"
  end

  def self.tencent_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.qq.com/")

    while (elements = session.find_elements(:css, ".textpanel-source-textarea textarea"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    result = [] of Selenium::Element

    loop do
      result = session.find_elements(:css, ".textpanel-target-textblock span.text-dst")

      break unless result.empty?

      sleep 1
    end

    puts "---------------Tencent---------------\n#{result.first.text}"
  end

  def self.alibaba_translater(session, content, debug_mode)
    session.navigate_to("https://translate.alibaba.com/")

    while (elements = session.find_elements(:css, "textarea#source"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.01
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    result = [] of Selenium::Element

    loop do
      result = session.find_elements(:css, "pre#pre")

      break unless result.empty?

      sleep 1
    end

    puts "---------------alibaba---------------\n#{result.first.text}"
  end

  at_exit do
    session.delete unless session.nil?
    driver.stop unless driver.nil?
  end
end
