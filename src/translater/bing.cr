class Translater
  class Bing
    def initialize(browser, content, debug_mode, chan, start_time)
      session, _driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://www.bing.com/translator")

      document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

      source_content_ele = session.find_by_selector_timeout("textarea#tta_input_ta", timeout: 1)

      session.find_by_selector_timeout("select#tta_tgtsl")

      if !content.matches? /\p{Han}/
        # 如果输入内容是英文, 修改目标语言为中文
        document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl"); select.value = "zh-Hans"})
      end

      source_content_ele.click

      Translater.input(source_content_ele, content, wait_seconds: 0.1)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      while result = document_manager.execute_script(%{return document.querySelector("textarea#tta_output_ta").value})
        break unless result.strip == "..."

        sleep 0.1
      end

      chan.send({result, self.class.name.split(":")[-1], Time.monotonic - start_time, browser})
    rescue Socket::ConnectError
    ensure
      session.delete if session
      # driver.stop if driver
    end
  end
end
