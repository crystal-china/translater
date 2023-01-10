require "option_parser"
require "selenium"
require "./bing_translater/*"

ARGV << STDIN.gets.not_nil! if STDIN.info.type.pipe?

ARGV << "--help" if ARGV.empty?

content = ARGV[-1]

target_language = "Chinese"

OptionParser.parse do |parser|
  parser.banner = <<-USAGE
Usage: bing_translater <option> content
USAGE

  parser.on("-t TARGET", "--target=TARGET", "Specify target language") do |target|
    case target
    when "zh-CN"
      target_language = "Chinese"
    when "en"
      target_language = "English"
    else
      puts "Supported options: -t zh-CN|en"
      exit
    end
  end

  parser.on("-h", "--help", "Show this help message and exit") do
    puts parser
    exit
  end

  parser.on("-v", "--version", "Show version") do
    puts BingTranslater::VERSION
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
  driver_path: "~/utils/bin/geckodriver"
) if content != "--help"

module BingTranslater
  def self.translate(target_language, content, driver_path)
    service = Selenium::Service.firefox(driver_path: File.expand_path(driver_path, home: true))

    driver = Selenium::Driver.for(:firefox, service: service)

    firefox_options = Selenium::Firefox::Capabilities::FirefoxOptions.new
    firefox_options.args = ["--headless"]

    capabilities = Selenium::Firefox::Capabilities.new
    capabilities.firefox_options = firefox_options

    session = driver.create_session(capabilities)

    session.navigate_to("https://www.bing.com/translator")

    source_content_ele = session.find_element(:css, "textarea#tta_input_ta")

    content.each_char do |e|
      source_content_ele.send_keys(key: e.to_s)
      sleep 0.02
    end

    # Clean Cookies
    cookie_manager = Selenium::CookieManager.new(command_handler: session.command_handler, session_id: session.id)
    cookie_manager.delete_all_cookies

    x = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

    if target_language == "Chinese"
      x.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "zh-Hans"})
    end

    result = ""

    loop do
      result = x.execute_script(%{return document.querySelector("textarea#tta_output_ta").value})

      break unless result.strip == "..."

      sleep 0.1
    end

    puts result
  ensure
    session.delete unless session.nil?
    driver.stop unless driver.nil?
  end
end
