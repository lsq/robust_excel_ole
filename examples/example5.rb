# example 5: open with :if_unsaved => :accept, close with :if_unsaved => :save 

require File.join(File.dirname(__FILE__), '../lib/robust_excel_ole')

module RobustExcelOle

    ExcelApp.close_all
    begin
	  file_name = '../spec/data/simple.xls' 
	  book = RobustExcelOle::Book.open(file_name)                      # open a book 
	  sheet = book[0]                                                  # access a sheet
	  sheet[0,0] = sheet[0,0].value == "simple" ? "complex" : "simple" # change a cell
	  begin
	    new_book = RobustExcelOle::Book.open(file_name)     # open another book with the same file name
	  rescue ExcelErrorOpen => msg                          # by default: raises an exception:
	    puts "open error: #{msg.message}"                   # a book with the same name is already open and unsaved 
	  end
	  new_book = RobustExcelOle::Book.open(file_name, :if_unsaved => :accept) # open another book with the same file name 
	                                                                          # and let the unsaved book open
	  if book.alive? && new_book.alive? then                # check whether the referenced workbooks
	  	puts "the two books are alive."                     # respond to methods
	  end
	  begin                                                                   
	  	book.close                                          # close the book. by default: raises an exception:
	  rescue ExcelErrorClose => msg                         #   book is unsaved
	  	puts "close error: #{msg.message}"
	  end
	  book.close(:if_unsaved => :save)                      # save the book before closing it 
	  puts "closed the book successfully with option :if_unsaved => :save"
	  new_book.close                                        # close the other book. It is already saved.
	ensure
  	  ExcelApp.close_all                                    # close workbooks, quit Excel application
	end

end