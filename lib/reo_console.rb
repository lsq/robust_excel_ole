require 'pry'
require 'robust_excel_ole'
include REO
# include RobustExcelOle
include General

puts 'REO console started'
puts 


# some pry configuration
Pry.config.windows_console_warning = false
Pry.config.history.should_save = true
#Pry.editor = 'notepad'  # 'subl', 'vi'
#Pry.config.prompt =
#  [
#    ->(_obj, _nest_level, _) { ">> " },
#    ->(*) { "  " }
#  ]

pry
