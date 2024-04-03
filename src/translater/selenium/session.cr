require "timeout"

class Selenium::Session
  def find_by_selector_timeout(selector : String, *, was_hidden : Bool = false, timeout seconds : Number = 0.5)
    element : Selenium::Element? = nil

    timeout(seconds) do
      until element = find_by_selector(selector, was_hidden: was_hidden)
        sleep 0.1
      end
    end

    element.not_nil!
  rescue e : Timeout::Error
    STDERR.puts "CSS selector #{selector} was timeout!"
    exit(1)
  end

  private def find_by_selector(selector : String, *, was_hidden : Bool = false) : Selenium::Element?
    elements = find_elements(:css, selector)

    return nil if elements.empty?

    e = elements.first

    if e.displayed?
      e
    else
      if was_hidden
        e
      else
        nil
      end
    end
  end
end
