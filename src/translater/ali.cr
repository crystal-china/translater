class Translater
  class Ali
    # ali only support at most three hundred words english to translate.
    # so split the translate content into chunk less than 300 words
    def input(t, ele, content, document_manager, session)
      # 阿里的 input_selector 和 output_selector 总是都存在，因此可以使用 js 清除（类似于腾讯)
      input_selector = "textarea#source"
      output_selector = "pre#pre"

      document_manager.execute_script(%{select = document.querySelector("#{input_selector}"); select.value = "";})

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

      String.build do |io|
        chunked_content.each do |c|
          t.input(ele, c)

          result = session.find_by_selector_wait!(output_selector) { |e| !e.text.blank? }

          io << result.text
          io << ", "

          document_manager.execute_script(%{select = document.querySelector("#{input_selector}"); select.value = "";})
          document_manager.execute_script(%{select = document.querySelector("#{output_selector}"); select.innerText = "";})

          sleep 0.1
        end
      end
    end

    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:ali, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://translate.alibaba.com/")

      source_content_ele = session.find_by_selector_wait! "textarea#source"
      source_content_ele.click

      document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

      text = input(t, source_content_ele, content, document_manager, session)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      chan.send({text, self.class.name.split(":")[-1], Time.monotonic - start_time, browser, is_new_session})
    rescue e : Socket::ConnectError
      STDERR.puts e.message
      exit 1
    rescue e : Selenium::Error
      STDERR.puts e.message
      abort "Network connection error?"
    ensure
      session.delete if session
      # driver.stop if driver
    end
  end
end
