class Translater
  class Youdao
    def initialize(session, content, debug_mode)
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

      puts "---------------Youdao---------------\n#{result.text}"
    end

    def initialize(chan, content)
      url = "https://fanyi.baidu.com/"
      doc = Crystagiri::HTML.from_url url, follow: true

      # until (source_content_ele = session.find_by_selector("textarea#source"))
      #   sleep 0.2
      # end

      # puts doc.content
      loop do
        input = doc.at_css("span.app-guide-close")
        p input
        sleep 1
      end

      # until (input = doc.at_css("#js_fanyi_input"))
      #   sleep 0.2
      # end

      puts "---------------Youdao---------------\n#{Time.local}"
    end
  end
end
