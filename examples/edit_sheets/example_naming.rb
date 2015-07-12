# example_naming.rb: 
# each cell is named with the name equaling its value unless it is empty or not a string
# the contents of each cell is copied
# the new workbook's name is extended by the suffix "_named"

require 'rubygems'
require 'robust_excel_ole'
require "fileutils"

include RobustExcelOle

begin
  Excel.close_all
  dir = "C:/data"
  workbook_name = 'workbook.xls'
  base_name = workbook_name[0,workbook_name.rindex('.')]
  suffix = workbook_name[workbook_name.rindex('.')+1,workbook_name.length]
  file_name = dir + "/" + workbook_name
  extended_file_name = dir + "/" + base_name + "_named" + "." + suffix
  book_orig = Book.open(file_name)
  book_orig.save_as(extended_file_name, :if_exists => :overwrite) 
  book_orig.close
  Book.unobtrusively(extended_file_name) do |book|     
    book.each do |sheet|
      sheet.each do |cell_orig|
        contents = cell_orig.Value
        sheet.add_name(cell_orig.Row,cell_orig.Column,contents) if contents && contents.class == String
      end
    end
  end
end
