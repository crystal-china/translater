class Translater
  class Baidu
    def initialize(browser, content, debug_mode, chan, start_time)
      session, _driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://fanyi.baidu.com/")

      # while session.find_by_selector ".desktop-guide"
      #   until (element = session.find_by_selector "a.desktop-guide-close")
      #     sleep 0.1
      #   end

      #   element.click
      # end

      session.find_by_selector_timeout("div[style*=\"display: block;\"][style^=\"background-color\"]>div>div>span", timeout: 1).click

      # while session.find_by_selector "#app-guide"
      #   until (element = session.find_by_selector "span.app-guide-close")
      #     sleep 0.1
      #   end

      #   element.click
      # end

      # until (source_content_ele = session.find_by_selector("textarea#baidu_translate_input"))
      #   sleep 0.1
      # end

      source_content_ele = session.find_by_selector_timeout "div[data-slate-node=\"element\"", timeout: 0.5

      source_content_ele.click

      Translater.input(source_content_ele, content, wait_seconds: 0.1)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      # result = session.find_by_selector_timeout(".output-bd")

      result = session.find_by_selector_timeout "span[disabled][spellcheck=\"false\"]", timeout: 2

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
