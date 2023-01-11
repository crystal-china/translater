require "option_parser"
require "selenium"
require "webdrivers"
require "./bing_translater/*"

target_language = "Chinese"
browser = "firefox"
debug_mode = false
stdin = [] of String
content = ""

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
    "-e ENGINE",
    "--target=ENGINE",
    "Specify engine, only support firefox for now, default is firefox.
") do |engine|
    case engine
    when "firefox"
      browser = "firefox"
    when "chrome"
      browser = "chrome"
    else
      STDERR.puts "Supported options: -e firefox"
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

BingTranslater.translate(
  target_language: target_language,
  content: content,
  debug_mode: debug_mode,
  browser: browser
) if content != "--help"

module BingTranslater
  def self.translate(target_language, content, debug_mode, browser)
    case browser
    when "firefox"
      driver_path = Webdrivers::Geckodriver.install
      service = Selenium::Service.firefox(driver_path: File.expand_path(driver_path, home: true))
      driver = Selenium::Driver.for(:firefox, service: service)
      options = Selenium::Firefox::Capabilities::FirefoxOptions.new
      options.args = ["--headless"] unless debug_mode == true

      capabilities = Selenium::Firefox::Capabilities.new
      capabilities.firefox_options = options
    when "chrome"
      driver_path = Webdrivers::Chromedriver.install
      service = Selenium::Service.chrome(driver_path: File.expand_path(driver_path, home: true))
      driver = Selenium::Driver.for(:chrome, service: service)

      options = Selenium::Chrome::Capabilities::ChromeOptions.new
      options.args = ["headless"] unless debug_mode == true

      capabilities = Selenium::Chrome::Capabilities.new
      capabilities.chrome_options = options
    else
      STDERR.puts "Only support firefox|chrome, firefox is default."
      exit
    end

    session = driver.create_session(capabilities)

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

    # Clean Cookies
    cookie_manager = Selenium::CookieManager.new(command_handler: session.command_handler, session_id: session.id)
    cookie_manager.delete_all_cookies

    x = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

    case target_language
    when "Chinese"
      x.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "zh-Hans"})
    when "English"
      x.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "en"})
    end

    gets if debug_mode

    result = ""

    loop do
      result = x.execute_script(%{return document.querySelector("textarea#tta_output_ta").value})

      break unless result.strip == "..."

      sleep 0.1
    end

    STDERR.puts result
  rescue e : Selenium::Error
    STDERR.puts e.message
    exit
  ensure
    session.delete unless session.nil?
    driver.stop unless driver.nil?
  end
end
