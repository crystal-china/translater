require "selenium"

class Translater
  class Driver
    macro for(engine, base_url)
      driver = Selenium::Driver.for({{ engine }}, base_url: {{ base_url }})

      {% if engine == :firefox %}
        driver_binary = "geckodriver"
      {% elsif engine == :chrome %}
        driver_binary = "chromedriver"
      {% end %}

      if !chrome_ready?(driver)
        driver_paths = ["/usr/local/bin/#{driver_binary}", "/usr/bin/#{driver_binary}"]

        driver_path = driver_paths.each do |path|
          break path if File.executable? path
        end

        if driver_path.nil?
          abort "#{driver_paths.join(" or ")} not exists! Please install correct version Selenium driver before continue, exit ..."
        end

        service = Selenium::Service.{{ engine.id }}(driver_path: driver_path)
        driver = Selenium::Driver.for({{ engine }}, service: service)
      end

      driver
    end
  end
end
