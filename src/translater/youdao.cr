class Translater
  class Youdao
    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:youdao, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://fanyi.youdao.com/index.html#")

      if (ele1 = session.find_by_selector_timeout ".pop-up-comp.mask img.close", timeout: 0.5)
        ele1.click
      end

      session.find_by_selector_wait!("div.tab-item.active.color_text_1").click

      input_selector = "div#js_fanyi_input"
      output_selector = "div#js_fanyi_output_resultOutput"

      input_ele = session.find_by_selector_wait!(input_selector)

      # 有道行为和百度类似。

      # 如果上次的翻译有残留
      if !input_ele.text.blank?
        # 清除翻译内容
        # input_ele.clear
        # input_ele.send_keys(" ")
        document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)
        document_manager.execute_script(%{select = document.querySelector("#{input_selector}"); select.textContent = "" ;})
        document_manager.execute_script(%{select = document.querySelector("#{output_selector}"); select.textContent = "" ;})

        # 确保数据结果元素不存在（当翻译内容为空时不存在）
        session.find_by_selector_wait_disappear!(output_selector)

        # 如果清除了上次的输入，需要重新查找输入元素
        input_ele = session.find_by_selector_wait!(input_selector)
      end

      input_ele.click

      t.input(input_ele, content)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      # 确保找到 output_selector 的元素，并且元素文本为空，否则重试
      result = session.find_by_selector_wait!(output_selector) { |e| !e.text.blank? }

      chan.send({result.text, self.class.name.split(":")[-1], Time.monotonic - start_time, browser, is_new_session})
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
