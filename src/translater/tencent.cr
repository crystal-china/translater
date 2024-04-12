class Translater
  class Tencent
    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:tencent, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://fanyi.qq.com/")

      input_selector = ".textpanel-source.active .textpanel-source-textarea textarea.textinput"
      output_selector = ".textpanel-target-textblock"

      input_ele = session.find_by_selector_wait! input_selector

      if !input_ele.text.blank?
        input_ele.clear

        session.find_by_selector_wait!(output_selector) { |e| e.text.blank? }

        input_ele = session.find_by_selector_wait! input_selector
      end

      input_ele.click

      t.input(input_ele, content)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      result = session.find_by_selector_wait!(output_selector) { |e| !e.text.blank? }

      chan.send({result.text, self.class.name.split(":")[-1], Time.monotonic - start_time, browser, is_new_session})
    rescue e : Socket::ConnectError
      STDERR.puts e.message
      exit 1
    rescue e : Selenium::Error
      STDERR.puts e.message
      abort "Network connection error?"
      # ensure
      #   session.delete if session
      # driver.stop if driver
    end
  end
end
