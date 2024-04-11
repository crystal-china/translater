class Translater
  class Bing
    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:bing, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://www.bing.com/translator")

      document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

      input_selector = "textarea#tta_input_ta"
      output_selector = "textarea#tta_output_ta"
      language_selector = "select#tta_tgtsl"

      input_ele = session.find_by_selector_wait! input_selector

      language_selector_ele = session.find_by_selector_wait! "#{language_selector} option"

      if target_language.chinese? && language_selector_ele.text != "Chinese Simplified"
        # 如果输入内容是英文, 修改目标语言为中文
        document_manager.execute_script(%{select = document.querySelector("#{language_selector}"); select.value = "zh-Hans"})
      end

      input_ele.click

      t.input(input_ele, content, wait_seconds: 0.1)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      while (result = document_manager.execute_script %{return document.querySelector("#{output_selector}").value})
        break unless result.strip == "..."

        sleep 0.1
      end

      chan.send({result, self.class.name.split(":")[-1], Time.monotonic - start_time, browser, is_new_session})
    rescue e : Socket::ConnectError
      STDERR.puts e.message
      exit 1
    rescue e : Selenium::Error
      STDERR.puts e.message
      abort "Network connection error?"
    ensure
      session.delete if session
      # driver.stop if driver
    end
  end
end
