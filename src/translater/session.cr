class Selenium::Session
  def find_by_selector(selector : String, *, displayed : Bool = true)
    elements = find_elements(:css, selector)

    return nil if elements.empty?

    e = elements.first

    return e unless displayed

    if e.displayed?
      e
    else
      nil
    end
  end
end
