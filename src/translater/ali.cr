class Translater
  class Ali
    def initialize(browser, content, debug_mode, chan, start_time)
      session, driver = Translater.create_driver(browser, debug_mode).not_nil!
      session.navigate_to("https://translate.alibaba.com/")

      until (source_content_ele = session.find_by_selector("textarea#source"))
        sleep 0.1
      end

      source_content_ele.click

      # ali only support at most three hundred words english to translate.
      # so split the translate content into chunk less than 300 words
      document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

      original_ary = content.split(/,|\./)
      str = ""

      chunked_ary = original_ary.chunk_while do |x, y|
        str = str + x
        if (str.size + y.size) > 290
          str = ""
          false
        else
          true
        end
      end

      chunked_content = chunked_ary.to_a.map(&.join)

      text = String.build do |io|
        chunked_content.each do |c|
          Translater.input(source_content_ele, c)

          until (result = session.find_by_selector("pre#pre"))
            sleep 0.1
          end

          while result.text.blank?
            sleep 0.1
          end

          io << result.text
          io << ", "

          document_manager.execute_script(%{select = document.querySelector("textarea#source"); select.value = "";})
          document_manager.execute_script(%{select = document.querySelector("pre#pre"); select.innerText = "";})

          sleep 0.1
        end
      end

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      chan.send({text, self.class.name.split(":")[-1], Time.monotonic - start_time, browser})
    rescue Socket::ConnectError
    ensure
      session.delete if session
      # driver.stop if driver
    end
  end
end
