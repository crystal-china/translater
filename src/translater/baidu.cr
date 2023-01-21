class Translater
  class Baidu
    def initialize(session, content, debug_mode)
      session.navigate_to("https://fanyi.baidu.com/")

      while session.find_by_selector "#app-guide"
        while (element = session.find_by_selector "span.app-guide-close")
          element.click

          sleep 0.2
        end

        break if session.find_by_selector ".app-guide-hide"

        sleep 0.2
      end

      until (source_content_ele = session.find_by_selector("textarea#baidu_translate_input"))
        sleep 0.2
      end

      source_content_ele.click

      sleep 0.2

      Translater.input(source_content_ele, content)

      if debug_mode
        STDERR.puts "Press any key to continue ..."
        gets
      end

      until result = session.find_by_selector("p.ordinary-output.target-output")
        sleep 0.2
      end

      while result.text.blank?
        sleep 0.2
      end

      puts "---------------Baidu---------------\n#{result.text}"
    end
  end
end
