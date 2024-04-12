# FIXME: volc still not work!

class Translater
  class Volc
    def initialize(browser, content, debug_mode, chan, start_time, target_language)
      t = Translater.new(:volc, debug_mode, target_language)
      session, is_new_session = t.find_or_create_firefox_session

      session.navigate_to("https://translate.volcengine.com")

      document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

      document_manager.execute_script <<-'HEREDOC'
            // overwrite the `languages` property to use a custom getter
            Object.defineProperty(navigator, 'languages', {
              get: function() {
                return ['en-US', 'en'];
              },
            });

            // overwrite the `plugins` property to use a custom getter
            Object.defineProperty(navigator, 'plugins', {
              get: function() {
                // this just needs to have `length > 0`, but we could mock the plugins too
                return [1, 2, 3, 4, 5];
              },
            });

      const getParameter = WebGLRenderingContext.getParameter;
      WebGLRenderingContext.prototype.getParameter = function(parameter) {
        // UNMASKED_VENDOR_WEBGL
        if (parameter === 37445) {
          return 'Intel Open Source Technology Center';
        }
        // UNMASKED_RENDERER_WEBGL
        if (parameter === 37446) {
          return 'Mesa DRI Intel(R) Ivybridge Mobile ';
        }

        return getParameter(parameter);
      };

      ['height', 'width'].forEach(property => {
        // store the existing descriptor
        const imageDescriptor = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, property);

        // redefine the property with a patched descriptor
        Object.defineProperty(HTMLImageElement.prototype, property, {
          ...imageDescriptor,
          get: function() {
            // return an arbitrary non-zero dimension if the image failed to load
            if (this.complete && this.naturalHeight == 0) {
              return 20;
            }
            // otherwise, return the actual dimension
            return imageDescriptor.get.apply(this);
          },
        });
      });

      // store the existing descriptor
      const elementDescriptor = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetHeight');

      // redefine the property with a patched descriptor
      Object.defineProperty(HTMLDivElement.prototype, 'offsetHeight', {
        ...elementDescriptor,
        get: function() {
          if (this.id === 'modernizr') {
              return 1;
          }
          return elementDescriptor.get.apply(this);
        },
      });
      HEREDOC

      session.find_by_selector_wait! "span[data-slate-placeholder='true']"

      # 这两个总是存在
      input_editor_selector = "div.slate-editor[contenteditable='true']"
      output_editor_selector = "div.slate-editor[contenteditable='false']"

      # 这两个有内容时才存在
      _input_selector = "#{input_editor_selector} span[data-slate-string='true']"
      output_selector = "#{output_editor_selector} span[data-slate-string='true']"

      input_ele = session.find_by_selector_wait! input_editor_selector
      session.find_by_selector_wait! output_editor_selector

      input_ele.click

      input_ele.send_keys("hello world!")

      content.each_char do |e|
        input_ele.send_keys(key: e.to_s)
        sleep 0.1
      end

      if debug_mode
        STDERR.puts "Press ENTER key to continue ..."
        gets
      end

      result = session.find_by_selector_wait!(output_selector) { |e| e.text.strip != "..." }

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
