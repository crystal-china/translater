class Translater
  class Baidu
    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:baidu, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://fanyi.baidu.com/")

      # 百度的行为：
      # 1. input_selector 总是存在, 而且必须是 div
      # 2. 如果上次用户输入有残留，inputed_selector 存在
      # 3. 当删除用户上次输入时，output_selector 会消失，重新输入，会存在。
      input_selector = "div[role='textbox'][contenteditable='true']"
      inputed_selector = "span[data-slate-string='true']"
      output_selector = "span[disabled][spellcheck='false']"

      # 如果有这个元素存在，则一定有上次输入的文本
      if session.find_by_selector_timeout inputed_selector
        document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)
        document_manager.execute_script(%{select = document.querySelector("#{inputed_selector}"); select.textContent = "" ;})

        session.find_by_selector_wait_disappear! output_selector
      else
        # 这个弹窗有时候有, 有时候没有, 所以, 还得保留
        if (ele1 = session.find_by_selector_timeout "div[style*='display: block;'][style^='background-color']>div>div>span")
          ele1.click
        end

        # 不知道是什么，有时候会出现，遮挡输入框
        session.find_by_selector_wait_disappear!("div.ant-row.ant-row-center.ant-row-middle")
      end

      input_ele = session.find_by_selector_wait! input_selector
      input_ele.click

      # 百度有检测，不可以粘贴，必须全部手动输入
      content.each_char do |e|
        input_ele.send_keys(key: e.to_s)
        sleep 0.05
      end

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      result = session.find_by_selector_wait!(output_selector) { |e| !e.text.blank? }

      chan.send({result.text, self.class.name.split(":")[-1], Time.monotonic - start_time, browser, is_new_session})
    rescue e : Socket::ConnectError
      # e.inspect_with_backtrace(STDERR)
      STDERR.puts e.message
      exit 1
    rescue e : Selenium::Error
      # e.inspect_with_backtrace(STDERR)
      STDERR.puts e.message
      abort "Network connection error?"
      # ensure
      #   session.delete if session
      # driver.stop if driver
    end
  end
end
