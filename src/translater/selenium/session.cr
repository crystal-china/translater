class Selenium::Session
  def find_by_selector(selector : String, *, was_hidden : Bool = false)
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
