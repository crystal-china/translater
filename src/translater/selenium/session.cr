class Selenium::WaitTimeoutError < Exception
end

class Selenium::Session
  DEFAULT_WAIT_TIMEOUT = 10.seconds
  WAIT_INTERVAL        = 50.milliseconds

  def find_by_selector_timeout(selector : String, *, was_hidden : Bool = false, timeout seconds : Number = 0.2)
    deadline = Time.instant + seconds.seconds

    loop do
      if element = find_by_selector(selector, was_hidden: was_hidden)
        return element
      end

      return if Time.instant >= deadline

      sleep WAIT_INTERVAL
    end
  end

  def find_by_selector_wait!(selector : String, *, was_hidden : Bool = false, timeout : Time::Span = DEFAULT_WAIT_TIMEOUT, &) : Selenium::Element
    deadline = Time.instant + timeout

    loop do
      if (element = find_by_selector selector, was_hidden: was_hidden) && yield(element)
        return element
      end

      wait_for_next_poll(deadline, timeout, selector, "match the expected condition")
    end
  end

  def find_by_selector_wait!(selector : String, *, was_hidden : Bool = false, timeout : Time::Span = DEFAULT_WAIT_TIMEOUT) : Selenium::Element
    deadline = Time.instant + timeout

    loop do
      if element = find_by_selector selector, was_hidden: was_hidden
        return element
      end

      wait_for_next_poll(deadline, timeout, selector, "appear")
    end
  end

  def find_by_selector_wait_disappear!(selector : String, *, was_hidden : Bool = false, timeout : Time::Span = DEFAULT_WAIT_TIMEOUT)
    deadline = Time.instant + timeout

    loop do
      return unless find_by_selector(selector, was_hidden: was_hidden)

      wait_for_next_poll(deadline, timeout, selector, "disappear")
    end
  end

  private def find_by_selector(selector : String, *, was_hidden : Bool = false) : Selenium::Element?
    elements = find_elements(:css, selector)

    return if elements.empty?

    e = elements.first

    e if e.displayed? || was_hidden
  end

  private def wait_for_next_poll(deadline : Time::Instant, timeout : Time::Span, selector : String, condition : String)
    if Time.instant >= deadline
      raise Selenium::WaitTimeoutError.new(
        "Timed out after #{timeout.total_seconds} seconds waiting for CSS selector #{selector.inspect} to #{condition}."
      )
    end

    sleep WAIT_INTERVAL
  end
end
