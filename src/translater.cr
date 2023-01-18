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

    parser.unknown_args do |args|
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

    parser.on("-D", "--debug", "Debug mode") do
      debug_mode = true
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
          # bing_translater(session, content, debug_mode, target_language) if engine_list.includes? Engine::Bing
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
      when timeout (engine_list.size * 10).seconds
        STDERR.puts %{Timeout! engine: #{engine_list.join(", ")}}
      end
    end
  end

  # def self.bing_translater(session, content, debug_mode, target_language)
  #   session.navigate_to("https://www.bing.com/translator")

  #   while session.find_elements(:css, "select#tta_tgtsl optgroup#t_tgtRecentLang option").empty?
  #     sleep 0.2
  #   end

  #   source_content_ele = session.find_element(:css, "textarea#tta_input_ta")
  #   source_content_ele.click

  #   sleep 0.2

  #   if content.size > 10
  #     content1 = content[0..-10]
  #     content2 = content[-9..-1]

  #     source_content_ele.send_keys(key: content1)
  #     content2.each_char do |e|
  #       source_content_ele.send_keys(key: e.to_s)
  #       sleep 0.05
  #     end
  #   else
  #     content.each_char do |e|
  #       source_content_ele.send_keys(key: e.to_s)
  #       sleep 0.05
  #     end
  #   end

  #   document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

  #   case target_language
  #   in TargetLanguage::English
  #     document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "en"})
  #   in TargetLanguage::Chinese
  #     document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "zh-Hans"})
  #   end

  #   if debug_mode
  #     STDERR.puts "Press any key to continue ..."
  #     gets
  #   end

  #   while result = document_manager.execute_script(%{return document.querySelector("textarea#tta_output_ta").value})
  #     break unless result.strip == "..."

  #     sleep 0.2
  #   end

  #   puts "---------------Bing---------------\n#{result}"
  # end

  def self.youdao_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.youdao.com/index.html")

    while (elements = session.find_elements(:css, "#js_fanyi_input"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first
    source_content_ele.click

    sleep 0.2

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    while results = session.find_elements(:css, "#js_fanyi_output_resultOutput")
      break unless results.empty?

      sleep 0.2
    end

    while result = results.first
      break unless result.text.blank?

      sleep 0.2
    end

    puts "---------------Youdao---------------\n#{result.text}"
  end

  def self.tencent_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.qq.com/")

    while (elements = session.find_elements(:css, ".textpanel-source.active .textpanel-source-textarea textarea.textinput"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first

    while !source_content_ele.displayed?
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    while results = session.find_elements(:css, ".textpanel-target-textblock span.text-dst")
      break unless results.empty?

      sleep 0.2
    end

    while result = results.first
      break unless result.text.blank?

      sleep 0.2
    end

    puts "---------------Tencent---------------\n#{result.text}"
  end

  def self.alibaba_translater(session, content, debug_mode)
    session.navigate_to("https://translate.alibaba.com/")

    while (elements = session.find_elements(:css, "textarea#source"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first

    while !source_content_ele.displayed?
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    while results = session.find_elements(:css, "pre#pre")
      break unless results.empty?

      sleep 0.2
    end

    while result = results.first
      break unless result.text.blank?

      sleep 0.2
    end

    puts "---------------Alibaba---------------\n#{result.text}"
  end

  def self.baidu_translater(session, content, debug_mode)
    session.navigate_to("https://fanyi.baidu.com/")

    while (elements = session.find_elements(:css, "#app-guide"); !elements.empty?)
      while (elements1 = session.find_elements(:css, "span.app-guide-close"); !elements1.empty?)
        while (element = session.find_element(:css, "span.app-guide-close")).displayed?
          element.click

          sleep 0.2
        end

        sleep 0.2
      end

      break if (elements = session.find_elements(:css, ".app-guide-hide"); !elements.empty?)

      sleep 0.2
    end

    while (elements = session.find_elements(:css, "textarea#baidu_translate_input"); elements.empty?)
      sleep 0.2
    end

    source_content_ele = elements.first

    while !source_content_ele.displayed?
      sleep 0.2
    end

    source_content_ele.click

    sleep 0.2

    if content.size > 10
      content1 = content[0..-10]
      content2 = content[-9..-1]

      source_content_ele.send_keys(key: content1)
      content2.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    else
      content.each_char do |e|
        source_content_ele.send_keys(key: e.to_s)
        sleep 0.05
      end
    end

    if debug_mode
      STDERR.puts "Press any key to continue ..."
      gets
    end

    while results = session.find_elements(:css, "p.target-output span")
      break unless results.empty?

      sleep 0.2
    end

    while result = results.first
      break unless result.text.blank?

      sleep 0.2
    end

    puts "---------------Baidu---------------\n#{result.text}"
  end

  at_exit do
    session.delete unless session.nil?
    driver.stop unless driver.nil?
  end
end
