class Translater
  class Youdao
    def initialize(session, content, debug_mode)
      session.navigate_to("https://fanyi.youdao.com/index.html")

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

      puts "---------------Youdao---------------\n#{result.text}"
    end
  end
end
