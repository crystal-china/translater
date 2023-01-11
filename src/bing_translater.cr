require "option_parser"
require "selenium"
require "webdrivers"
require "./bing_translater/*"

target_language = "Chinese"
browser = "Firefox"
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
    "Specify engine, support firefox|chrome for now, default is firefox.
") do |engine|
    case engine
    when "firefox"
      browser = "Firefox"
    when "chrome"
      browser = "Chrome"
    else
      STDERR.puts "Supported options: -e firefox|chrome"
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

  parser.on("-D", "--debug", "Debug 模式") do
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

webdriver_path = Webdrivers::Geckodriver.install

BingTranslater.translate(
  target_language: target_language,
  content: content,
  driver_path: webdriver_path,
  debug_mode: debug_mode
) if content != "--help"

module BingTranslater
  def self.translate(target_language, content, driver_path, debug_mode)
    service = Selenium::Service.firefox(driver_path: File.expand_path(driver_path, home: true))

    driver = Selenium::Driver.for(:firefox, service: service)

    firefox_options = Selenium::Firefox::Capabilities::FirefoxOptions.new
    firefox_options.args = ["--headless"] unless debug_mode == true

    capabilities = Selenium::Firefox::Capabilities.new
    capabilities.firefox_options = firefox_options

    session = driver.create_session(capabilities)

    session.navigate_to("https://www.bing.com/translator")

    source_content_ele = session.find_element(:css, "textarea#tta_input_ta")

    sleep 0.1

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

    sleep 10000 if debug_mode

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
