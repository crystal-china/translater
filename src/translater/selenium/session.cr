require "timeout"

class Selenium::Session
  # def find_by_selector_timeout!(selector : String, *, was_hidden : Bool = false, timeout seconds : Number = 0.5)
  #   element : Selenium::Element? = nil

  #   timeout(seconds) do
  #     until element = find_by_selector(selector, was_hidden: was_hidden)
  #       sleep 0.1
  #     end
  #   end

  #   element.not_nil!
  # rescue e : Timeout::Error
  #   e.inspect_with_backtrace(STDERR)
  #   STDERR.puts "CSS selector #{selector} was timeout for #{seconds} seconds!"
  #   exit(1)
  # end

  def find_by_selector_timeout(selector : String, *, was_hidden : Bool = false, timeout seconds : Number = 0.5)
    element : Selenium::Element? = nil

    timeout(seconds) do
      until (element = find_by_selector selector, was_hidden: was_hidden)
        sleep 0.1
      end
    end

    element.not_nil!
  rescue e : Timeout::Error
    # e.inspect_with_backtrace(STDERR)
    STDERR.puts "CSS selector #{selector} timeout for #{seconds} seconds!"
  end

  def find_by_selector_wait!(selector : String, *, was_hidden : Bool = false, &) : Selenium::Element
    element = nil

    loop do
      until (element = find_by_selector selector, was_hidden: was_hidden)
        sleep 0.1
      end

      result = yield element

      break element if result
    end

    element.not_nil!
  rescue
    STDERR.puts "CSS selector #{selector} is not exists."
    exit(1)
  end

  def find_by_selector_wait!(selector : String, *, was_hidden : Bool = false) : Selenium::Element
    until (element = find_by_selector selector, was_hidden: was_hidden)
      sleep 0.1
    end

    element
  rescue
    STDERR.puts "CSS selector #{selector} is not exists."
    exit(1)
  end

  def find_by_selector_wait_disappear!(selector : String, *, was_hidden : Bool = false)
    while find_by_selector(selector, was_hidden: was_hidden)
      sleep 0.1
    end
  rescue
    STDERR.puts "CSS selector #{selector} is never disppear."
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
