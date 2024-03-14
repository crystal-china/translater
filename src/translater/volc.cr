class Translater
  class Volc
    def initialize(session, content, debug_mode, chan, start_time)
      session.navigate_to("https://translate.volcengine.com")

      until session.find_by_selector "span[data-slate-placeholder=\"true\"]"
        sleep 0.1
      end

      until (source_content_ele = session.find_by_selector %{div.slate-editor[contenteditable="true"]})
        sleep 0.1
      end

      source_content_ele.click

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      until (result = session.find_by_selector "span[data-slate-string=\"true\"]")
        sleep 0.1
      end

      while result.text.blank?
        sleep 0.1
      end

      text = result.text

      chan.send({text, self.class.name.split(":")[-1], Time.monotonic - start_time})
    rescue Socket::ConnectError
    ensure
      session.delete
    end
  end
end
