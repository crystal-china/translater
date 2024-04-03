class Translater
  class Tencent
    def initialize(browser, content, debug_mode, chan, start_time)
      session, _driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://fanyi.qq.com/")

      source_content_ele = session.find_by_selector_timeout(".textpanel-source.active .textpanel-source-textarea textarea.textinput", timeout: 1)

      source_content_ele.click

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      result = session.find_by_selector_timeout(".textpanel-target-textblock", timeout: 2)

      while result.text.blank?
        sleep 0.1
      end

      text = result.text

      chan.send({text, self.class.name.split(":")[-1], Time.monotonic - start_time, browser})
    rescue Socket::ConnectError
    ensure
      session.delete if session
      # driver.stop if driver
    end
  end
end
