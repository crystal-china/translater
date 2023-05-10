class Translater
  class Tencent
    def initialize(session, content, debug_mode, chan, start_time)
      session.navigate_to("https://fanyi.qq.com/")

      until (source_content_ele = session.find_by_selector(".textpanel-source.active .textpanel-source-textarea textarea.textinput"))
        sleep 0.2
      end

      source_content_ele.click

      sleep 0.2

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press any key to continue ..."
        gets
      end

      until result = session.find_by_selector(".textpanel-target-textblock")
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
