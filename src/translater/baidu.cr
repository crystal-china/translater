class Translater
  class Baidu
    def initialize(session, content, debug_mode, chan, start_time)
      session.navigate_to("https://fanyi.baidu.com/")

      sleep 0.2

      while session.find_by_selector "#app-guide"
        until (element = session.find_by_selector "span.app-guide-close")
          sleep 0.2
        end

        element.click
      end

      while session.find_by_selector ".desktop-guide"
        while (element = session.find_by_selector "a.desktop-guide-close")
          element.click

          sleep 0.2
        end

        until session.find_by_selector ".desktop-guide-hide"
          sleep 0.2
        end

        break
      end

      until (source_content_ele = session.find_by_selector("textarea#baidu_translate_input"))
        sleep 0.2
      end

      source_content_ele.click

      sleep 0.2

      Translater.input(source_content_ele, content, wait_seconds: 0.1)

      if debug_mode
        STDERR.puts "Press any key to continue ..."
        gets
      end

      until result = session.find_by_selector(".output-bd")
        sleep 0.2
      end

      while result.text.blank?
        sleep 0.2
      end

      text = result.text

      chan.send({text, self.class.name.split(":")[-1], Time.monotonic - start_time})
    rescue Socket::ConnectError
    ensure
      session.delete
    end
  end
end
