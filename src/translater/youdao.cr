class Translater
  class Youdao
    def initialize(session, content, debug_mode, chan, start_time)
      session.navigate_to("https://fanyi.youdao.com/index.html")

      while session.find_by_selector ".pop-up-comp"
        while (element = session.find_by_selector "img.close")
          element.click

          sleep 0.2
        end

        sleep 0.2
      end

      while (element = session.find_by_selector ".never-show")
        element.click

        sleep 0.2
      end

      until (source_content_ele = session.find_by_selector("#js_fanyi_input"))
        sleep 0.2
      end

      source_content_ele.click

      sleep 0.2

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press any key to continue ..."
        gets
      end

      until result = session.find_by_selector("#js_fanyi_output_resultOutput")
        sleep 0.2
      end

      while result.text.blank?
        sleep 0.2
      end

      chan.send({result.text, self.class.name.split(":")[-1], Time.monotonic - start_time})
    ensure
      session.delete
    end
  end
end
