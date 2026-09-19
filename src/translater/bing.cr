class Translater
  class Bing
    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:bing, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://www.bing.com/translator")

      document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

      input_selector = "#tta_input_ta"
      output_selector = "#tta_output_ta"
      language_selector = "select#tta_tgtsl"

      input_ele = session.find_by_selector_wait! input_selector

      target_language_code = target_language.chinese? ? "zh-Hans" : "en"
      document_manager.execute_script(<<-JAVASCRIPT)
        select = document.querySelector("#{language_selector}");
        if (select.value !== "#{target_language_code}") {
          select.value = "#{target_language_code}";
          select.dispatchEvent(new Event("change", { bubbles: true }));
        }
        JAVASCRIPT

      input_ele.click

      t.input(input_ele, content, wait_interval: 100.milliseconds)

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      deadline = Time.instant + 10.seconds
      result = ""
      loop do
        result = document_manager.execute_script(
          %(return document.querySelector("#{output_selector}")?.innerText || "")
        ).strip

        break unless result.empty? || result == "..."

        if Time.instant >= deadline
          raise Selenium::WaitTimeoutError.new("Timed out waiting for Bing translation output.")
        end

        sleep 100.milliseconds
      end

      chan.send EngineResult.new(
        engine: Engine::Bing,
        text: result,
        elapsed: Time.instant - start_time,
        browser: browser,
        cached: !is_new_session,
        error: nil
      )
    end
  end
end
