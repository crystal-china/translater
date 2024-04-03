class Translater
  class Youdao
    def initialize(browser, content, debug_mode, chan, start_time)
      session, driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://fanyi.youdao.com/index.html#")

      until (element = session.find_by_selector ".pop-up-comp.mask img.close")
        sleep 0.1
      end

      element.click

      until (element1 = session.find_by_selector "div.tab-item.active.color_text_1")
        sleep 0.1
      end

      element1.click

      until (source_content_ele = session.find_by_selector("#js_fanyi_input"))
        sleep 0.1
      end

      source_content_ele.click

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      until (result = session.find_by_selector("#js_fanyi_output_resultOutput"))
        sleep 0.1
      end

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
