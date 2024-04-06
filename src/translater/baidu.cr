class Translater
  class Baidu
    def initialize(browser, content, debug_mode, chan, start_time)
      session, _driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://fanyi.baidu.com/")

      # # old baidu translate
      # session.find_by_selector_timeout("a.desktop-guide-close").click
      # session.find_by_selector_timeout("span.app-guide-close").click
      # source_content_ele = session.find_by_selector_timeout("textarea#baidu_translate_input", timeout: 1)

      session.find_by_selector_timeout("div[style*=\"display: block;\"][style^=\"background-color\"]>div>div>span", timeout: 1).click

      source_content_ele = session.find_by_selector_timeout "div[data-slate-node=\"element\""

      source_content_ele.click

      Translater.input(source_content_ele, content, wait_seconds: 0.1)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      result = session.find_by_selector_timeout "span[disabled][spellcheck=\"false\"]", timeout: 3

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
