require 'pry'
require '../robust_excel_ole/lib/robust_excel_ole'

include REO
include General

# some pry configuration
Pry.config.windows_console_warning = false
Pry.config.color = false
Pry.config.prompt_name = "REO "

#Pry.config.history_save = true
#Pry.editor = 'notepad'  # 'subl', 'vi'

prompt_proc1 = proc { |target_self, nest_level, pry|
   "[#{pry.input_ring.count}] #{pry.config.prompt_name}(#{Pry.view_clip(target_self.inspect)})#{":#{nest_level}" unless nest_level.zero?}> "
 }

prompt_proc2 =  proc { |target_self, nest_level, pry|
  "[#{pry.input_ring.count}] #{pry.config.prompt_name}(#{Pry.view_clip(target_self.inspect)})#{":#{nest_level}" unless nest_level.zero?}* "
 }

Pry.config.prompt = if RUBY_PLATFORM =~ /java/
  [prompt_proc1, prompt_proc2]
else
  Pry::Prompt.new(
    "REO",
    "The RobustExcelOle Prompt. Besides the standard information it puts the current object",
    [prompt_proc1, prompt_proc2]
    )
end

hooks = Pry::Hooks.new

hooks.add_hook :when_started, :hook12 do
puts 'REO console started'
puts
end

General.uplift_to_reo

Pry.start(nil, hooks: hooks)
