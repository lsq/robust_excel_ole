
# -*- coding: utf-8 -*-

module RobustExcelOle

  class Bookstore

    def initialize
      @filename2books ||= Hash.new {|hash, key| hash[key] = [] }
      @hidden_excel_instance = nil
    end

    # returns a book with the given filename, if it was open once
    # prefers open books to closed books, and among them, prefers more recently opened books
    # excludes hidden Excel instance
    # options: :prefer_writable   return the writable book, if it is open (default: true)
    #                             otherwise return the book according to the preference order mentioned above
    #          :prefer_excel      return the book in the given excel instance, if it exists,
    #                             otherwise proceed according to prefer_writable 
    def fetch(filename, options = {:prefer_writable => true })
      filename = absolute_path(filename)
      filename_key = RobustExcelOle::canonize(filename)
      weakref_books = @filename2books[filename_key]
      return nil unless weakref_books
      result = open_book = closed_book = nil      
      weakref_books.each do |wr_book|
        if (not wr_book.weakref_alive?)
          begin 
            @filename2books[filename_key].delete(wr_book)
          rescue
            puts "Warning: deleting dead reference failed! (file: #{filename})"
          end
        else
          book = wr_book.__getobj__
          next if book.excel == try_hidden_excel
          if options[:prefer_excel] && book.excel == options[:prefer_excel]
            result = book
            break 
          end
          if book.alive?
            open_book = book
            break if (book.writable && options[:prefer_writable])
          else
            closed_book = book
          end
        end
      end
      result = result ? result : (open_book ? open_book : closed_book)
      result if result
    end

    # stores a book
    def store(book)
      filename_key = RobustExcelOle::canonize(book.filename)      
      if book.stored_filename
        old_filename_key = RobustExcelOle::canonize(book.stored_filename)
        # deletes the weak reference to the book
        @filename2books[old_filename_key].delete(book)
      end
      @filename2books[filename_key] |= [WeakRef.new(book)]
      book.stored_filename = book.filename
    end

    # creates and returns a separate Excel instance with Visible and DisplayAlerts false
    def hidden_excel
      unless (@hidden_excel_instance &&  @hidden_excel_instance.weakref_alive? && @hidden_excel_instance.__getobj__.alive?)       
        @hidden_excel_instance = WeakRef.new(Excel.create) 
      end
      @hidden_excel_instance.__getobj__
    end

  private

    def try_hidden_excel
      @hidden_excel_instance.__getobj__ if (@hidden_excel_instance &&  @hidden_excel_instance.weakref_alive? && @hidden_excel_instance.__getobj__.alive?)
    end

    # prints the book store
    def print
      p "@filename2books:"
      if @filename2books
        @filename2books.each do |filename,books|
          p " filename: #{filename}"
          p " books:"
          if books.empty? 
            p " []" 
          else
            books.each do |book|
              if book.weakref_alive?
                p "#{book}"
              else
                p "weakref not alive"
              end
            end
          end
        end
      end
    end

  end

  class BookstoreError < WIN32OLERuntimeError # :nodoc: #
  end
 
end