class Translater
  class Ali
    def initialize(session, content, debug_mode, chan, start_time)
      session.navigate_to("https://translate.alibaba.com/")

      until (source_content_ele = session.find_by_selector("textarea#source"))
        sleep 0.2
      end

      source_content_ele.click

      sleep 0.2

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press any key to continue ..."
        gets
      end

      until result = session.find_by_selector("pre#pre")
        sleep 0.2
      end

      while result.text.blank?
        sleep 0.2
      end

      text = result.text

      session.delete

      chan.send({text, self.class.name.split(":")[-1], Time.monotonic - start_time})
    end
  end
end
