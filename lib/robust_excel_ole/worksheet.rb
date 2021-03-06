# -*- coding: utf-8 -*-

module RobustExcelOle

  # This class essentially wraps a Win32Ole Worksheet object. 
  # You can apply all VBA methods (starting with a capital letter) 
  # that you would apply for a Worksheet object. 
  # see https://docs.microsoft.com/en-us/office/vba/api/excel.worksheet#methods


  # worksheet: see https://github.com/Thomas008/robust_excel_ole/blob/master/lib/robust_excel_ole/worksheet.rb
  class Worksheet < RangeOwners

    attr_reader :ole_worksheet
    attr_reader :workbook

    def initialize(win32_worksheet)
      @ole_worksheet = win32_worksheet
      if @ole_worksheet.ProtectContents
        @ole_worksheet.Unprotect
        @end_row = last_row
        @end_column = last_column
        @ole_worksheet.Protect
      else
        @end_row = last_row
        @end_column = last_column
      end
      @workbook = workbook_class.new(self.Parent)
    end

    # sheet name
    # @returns name of the sheet
    def name
      @ole_worksheet.Name
    rescue
      raise WorksheetREOError, "name #{name.inspect} could not be determined"
    end

    # sets sheet name
    # @param [String] new_name the new name of the sheet
    def name= (new_name)
      @ole_worksheet.Name = new_name
    rescue WIN32OLERuntimeError => msg
      if msg.message =~ /800A03EC/
        raise NameAlreadyExists, "sheet name #{new_name.inspect} already exists"
      else
        raise UnexpectedREOError, "unexpected WIN32OLERuntimeError: #{msg.message}"
      end
    end

    # a cell given the defined name or row and column
    # @params row, column, or name
    # @returns cell, if row and column are given
    def [] p1, p2 = :__not_provided
      if p2 != :__not_provided
        x, y = p1, p2
        xy = "#{x}_#{y}"
        @cells = { }
        begin
          @cells[xy] = RobustExcelOle::Cell.new(@ole_worksheet.Cells.Item(x, y))
        rescue
          raise RangeNotEvaluatable, "cannot read cell (#{x.inspect},#{y.inspect})"
        end
      else
        name = p1
        begin
          namevalue_glob(name)
        rescue REOError
          namevalue(name)
        end
      end
    end

    # sets the value of a cell
    # @params row and column, or defined name
    def []= (p1, p2, p3 = :__not_provided)
      if p3 != :__not_provided
        x, y, value = p1, p2, p3
        set_cellval(x,y,value)
      else
        name, value = p1, p2
        begin
          set_namevalue_glob(name, value, :color => 42) # aqua-marin, 4-green
        rescue REOError
          begin
            workbook.set_namevalue_glob(name, value)
          rescue REOError
            set_namevalue(name, value)
          end
        end
      end
    end

    # value of a cell, if row and column are given
    # @params row and column
    # @returns value of the cell
    def cellval(x,y)
      xy = "#{x}_#{y}"
      @cells = { }
      begin
        @cells[xy] = RobustExcelOle::Cell.new(@ole_worksheet.Cells.Item(x, y))
        @cells[xy].Value
      rescue
        raise RangeNotEvaluatable, "cannot read cell (#{p1.inspect},#{p2.inspect})"
      end
    end

    # sets the value of a cell, if row, column and color of the cell are given
    # @params [Integer] x,y row and column
    # @option opts [Symbol] :color the color of the cell when set
    def set_cellval(x,y,value, opts = {:color => 0})
      cell = @ole_worksheet.Cells.Item(x, y)
      cell.Interior.ColorIndex = opts[:color] # 42 - aqua-marin, 4-green
      @workbook.modified_cells << cell if @workbook
      cell.Value = value
    rescue WIN32OLERuntimeError
      raise RangeNotEvaluatable, "cannot assign value #{value.inspect} to cell (#{y.inspect},#{x.inspect})"
    end

    def each
      each_row do |row_range|
        row_range.each do |cell|
          yield cell
        end
      end
    end

    def each_with_index(offset = 0)
      i = offset
      each_row do |row_range|
        row_range.each do |cell|
          yield cell, i
          i += 1
        end
      end
    end

    def each_row(offset = 0)
      offset += 1
      1.upto(@end_row) do |row|
        next if row < offset
        yield RobustExcelOle::Range.new(@ole_worksheet.Range(@ole_worksheet.Cells(row, 1), @ole_worksheet.Cells(row, @end_column)))
      end
    end

    def each_row_with_index(offset = 0)
      each_row(offset) do |row_range|
        yield RobustExcelOle::Range.new(row_range), (row_range.Row - 1 - offset)
      end
    end

    def each_column(offset = 0)
      offset += 1
      1.upto(@end_column) do |column|
        next if column < offset
        yield RobustExcelOle::Range.new(@ole_worksheet.Range(@ole_worksheet.Cells(1, column), @ole_worksheet.Cells(@end_row, column)))
      end
    end

    def each_column_with_index(offset = 0)
      each_column(offset) do |column_range|
        yield RobustExcelOle::Range.new(column_range), (column_range.Column - 1 - offset)
      end
    end

    def row_range(row, integer_range = nil)
      integer_range ||= 1..@end_column
      RobustExcelOle::Range.new(@ole_worksheet.Range(@ole_worksheet.Cells(row, integer_range.min), @ole_worksheet.Cells(row, integer_range.max)))
    end

    def col_range(col, integer_range = nil)
      integer_range ||= 1..@end_row
      RobustExcelOle::Range.new(@ole_worksheet.Range(@ole_worksheet.Cells(integer_range.min, col), @ole_worksheet.Cells(integer_range.max, col)))
    end

    # @private
    def self.workbook_class  
      @workbook_class ||= begin
        module_name = self.parent_name
        "#{module_name}::Workbook".constantize
      rescue NameError => e
        Workbook
      end
    end

    # @private
    def workbook_class        
      self.class.workbook_class
    end

    # @private
    def to_s    
      '#<Worksheet: ' + ('not alive ' unless @workbook.alive?).to_s + name.to_s + " #{File.basename(@workbook.stored_filename)} >"
    end

    # @private
    def inspect  
      self.to_s
    end

  private

    # @private
    def method_missing(name, *args)
      if name.to_s[0,1] =~ /[A-Z]/
        begin
          @ole_worksheet.send(name, *args)
        rescue WIN32OLERuntimeError => msg
          if msg.message =~ /unknown property or method/
            raise VBAMethodMissingError, "unknown VBA property or method #{name.inspect}"
          else
            raise msg
          end
        end
      else
        super
      end
    end

    def last_row
      special_last_row = @ole_worksheet.UsedRange.SpecialCells(RobustExcelOle::XlLastCell).Row
      used_last_row = @ole_worksheet.UsedRange.Rows.Count

      special_last_row >= used_last_row ? special_last_row : used_last_row
    end

    def last_column
      special_last_column = @ole_worksheet.UsedRange.SpecialCells(RobustExcelOle::XlLastCell).Column
      used_last_column = @ole_worksheet.UsedRange.Columns.Count

      special_last_column >= used_last_column ? special_last_column : used_last_column
    end

  end

  public

  Sheet = Worksheet

end
