# example_concatening.rb: 
# each named cell gets the value of cell right to it appended to its own value
# the new workbook's name is extended by the suffix "_concat"

require 'rubygems'
require 'robust_excel_ole'
require "fileutils"

include RobustExcelOle

begin
  Excel.close_all
  dir = "C:/data"
  workbook_name = 'workbook_named_filled.xls'
  base_name, suffix = workbook_name.split(".")
  file_name = dir + "/" + workbook_name
  extended_file_name = dir + "/" + base_name + "_concat" + "." + suffix
  Excel.current.generate_workbook(extended_file_name)
  book_new = Book.open(extended_file_name, :visible => true)
  sheet_new  = book_new[0]
  excel = Excel.new(:reuse => false, :visible => true)
  Book.unobtrusively(file_name, :if_closed => excel, :keep_open => true) do |book_orig|     
    sheet_orig = book_orig[0]
    sheet_orig.each do |cell_orig|      
      name = cell_orig.Name.Name rescue nil
      if name
        sheet_new[cell_orig.Row-1, cell_orig.Column-1].Value = cell_orig.Value.to_s + cell_orig.Offset(0,1).Value.to_s
        sheet_new.Names.Add("Name" => name, "RefersTo" => "=" + cell_orig.Address) 
      end
    end
  end
  book_new.save
  #book_new.close
end

  
