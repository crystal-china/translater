# def self.bing_translater(session, content, debug_mode, target_language)
#   session.navigate_to("https://www.bing.com/translator")

#   # until (source_content_ele = session.find_by_selector("select#tta_tgtsl optgroup#t_tgtRecentLang option"))
#   #   sleep 0.2
#   # end

#   until source_content_ele = session.find_by_selector("textarea#tta_input_ta")
#     sleep 0.2
#   end

#   source_content_ele.click

#   sleep 0.2

#   input(source_content_ele, content)

#   document_manager = Selenium::DocumentManager.new(command_handler: session.command_handler, session_id: session.id)

#   case target_language
#   in TargetLanguage::English
#     document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "en"})
#   in TargetLanguage::Chinese
#     -      document_manager.execute_script(%{select = document.querySelector("select#tta_tgtsl optgroup#t_tgtRecentLang option"); select.value = "zh-Hans"})
#     -    end

#   if debug_mode
#     STDERR.puts "Press ENTER key to continue ..."
#     gets
#   end

#   while result = document_manager.execute_script(%{return document.querySelector("textarea#tta_output_ta").value})
#     break unless result.strip == "..."

#     sleep 0.2
#   end

#   puts "---------------Bing---------------\n#{result}"
# end
