class Translater
  class Youdao
    def initialize(browser, content, debug_mode, chan, start_time)
      session, _driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://fanyi.youdao.com/index.html#")

      session.find_by_selector_timeout(".pop-up-comp.mask img.close", timeout: 2).click

      session.find_by_selector_timeout("div.tab-item.active.color_text_1").click

      source_content_ele = session.find_by_selector_timeout("#js_fanyi_input")

      source_content_ele.click

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      result = session.find_by_selector_timeout("#js_fanyi_output_resultOutput", timeout: 3)

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
