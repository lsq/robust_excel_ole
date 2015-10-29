# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), './spec_helper')

$VERBOSE = nil

include RobustExcelOle

module RobustExcelOle

  describe Excel do

    before(:all) do
      Excel.kill_all
    end

    before do
      @dir = create_tmpdir
      #print "tmpdir: "; p @dir
      @simple_file = @dir + '/workbook.xls'
      @another_simple_file = @dir + '/another_workbook.xls'
      @different_file = @dir + '/different_workbook.xls'
      @invalid_name_file = 'b/workbook.xls'
    end

    after do
      Excel.kill_all
      rm_tmp(@dir)
    end

    context "excel creation" do
      
      def creation_ok? # :nodoc: #
        @excel.alive?.should be_true
        @excel.Visible.should be_false
        @excel.DisplayAlerts.should be_false
        @excel.Name.should == "Microsoft Excel"
      end

      it "should access excel.excel" do
        excel = Excel.new(:reuse => false)
        excel.excel.should == excel
        excel.excel.should be_a Excel
      end

      it "should work with 'new' " do
        @excel = Excel.new
        creation_ok?
      end

      it "should work with 'new' " do
        @excel = Excel.new(:reuse => false)
        creation_ok?
      end

      it "should work with 'reuse' " do
        excel = Excel.create
        @excel = Excel.new(:reuse => true)
        creation_ok?
        @excel.should === excel
        @excel = Excel.current
        creation_ok?
        @excel.should === excel
      end

      it "should work with 'create' " do
        excel = Excel.create
        @excel = Excel.new(:reuse => false)
        creation_ok?
        @excel.should_not == excel
        @excel = Excel.create
        creation_ok?
        @excel.should_not == excel
      end

      it "should work with reusing (uplifting) an Excel given as WIN32Ole object" do
        excel0 = Excel.create
        book = Book.open(@simple_file)
        excel = book.excel
        win32ole_excel = WIN32OLE.connect(book.workbook.Fullname).Application
        @excel = Excel.new(:reuse => win32ole_excel)
        creation_ok?
        @excel.should be_a Excel
        @excel.should be_alive
        @excel.should == excel
      end
    end

    context "with identity transparence" do

      before do
        @excel1 = Excel.create
      end

      it "should create different Excel instances" do
        excel2 = Excel.create
        excel2.should_not == @excel1
        excel2.Hwnd.should_not == @excel1.Hwnd
      end

      it "should reuse the existing Excel instances" do
        excel2 = Excel.current
        excel2.should === @excel1
        excel2.Hwnd.should == @excel1.Hwnd
      end

      it "should reuse existing Excel instance with default options for 'new'" do
        excel2 = Excel.new
        excel2.should === @excel1
        excel2.Hwnd.should == @excel1.Hwnd
      end

      it "should yield the same Excel instances for the same Excel objects" do
        excel2 = @excel1
        excel2.Hwnd.should == @excel1.Hwnd
        excel2.should === @excel1
      end
    end

    context "excel_processes" do
        
      before do
        @excel1 = Excel.create
        @excel2 = Excel.create
      end

      it "should yield Excel objects" do        
        excels = Excel.excel_processes    
        excels[0].should == @excel1
        excels[1].should == @excel2
      end

    end

    context "kill Excel processes hard" do

      before do
        @excel1 = Excel.create
        @excel2 = Excel.create
      end

      it "should kill Excel processes" do
        Excel.kill_all
        @excel1.alive?.should be_false
        @excel2.alive?.should be_false
      end

    end

    context "with recreating Excel instances" do

      it "should recreate a single Excel instance" do
        book = Book.open(@simple_file)
        excel = book.excel
        excel.close
        excel.should_not be_alive
        excel.recreate
        excel.should be_a Excel
        excel.should be_alive
        book.should be_alive
        excel.close
        excel.should_not be_alive
      end

      it "should recreate several Excel instances" do  
        book = Book.open(@simple_file)      
        book2 = Book.open(@another_simple_file, :force_excel => book)
        book3 = Book.open(@different_file, :force_excel => :new)
        excel = book.excel
        excel3 = book3.excel
        excel.close
        excel3.close
        excel.should_not be_alive
        excel3.should_not be_alive
        excel.recreate(:visible => true)
        excel.should be_alive
        excel.should be_a Excel
        excel.visible.should be_true
        excel.displayalerts.should be_false
        book.should be_alive
        book2.should be_alive
        book.excel.should == excel
        book2.excel.should == excel
        excel3.recreate(:visible => true, :displayalerts => true)
        excel3.should be_alive
        excel3.should be_a Excel
        excel3.visible.should be_true
        excel3.displayalerts.should be_true
        book3.should be_alive
        excel.close
        excel.should_not be_alive
        excel3.close
        excel3.should_not be_alive
      end
    end    

    context "close excel instances" do
      def direct_excel_creation_helper  # :nodoc: #
        expect { WIN32OLE.connect("Excel.Application") }.to raise_error
        sleep 0.1
        excel1 = WIN32OLE.new("Excel.Application")
        excel1.Workbooks.Add
        excel2 = WIN32OLE.new("Excel.Application")
        excel2.Workbooks.Add
        expect { WIN32OLE.connect("Excel.Application") }.to_not raise_error
      end

      it "simple file with default" do
        Excel.close_all
        direct_excel_creation_helper
        Excel.close_all
        sleep 0.1
        expect { WIN32OLE.connect("Excel.Application") }.to raise_error
      end
    end

    describe "close_all" do

      context "with saved workbooks" do

        before do
          book = Book.open(@simple_file)
          book2 = Book.open(@simple_file, :force_excel => :new)
          @excel = book.excel
          @excel2 = book2.excel
        end

        it "should close the Excel instances" do
          @excel.should be_alive
          @excel2.should be_alive
          Excel.close_all
          @excel.should_not be_alive
          @excel2.should_not be_alive
        end
      end

      context "with unsaved_workbooks" do
        
        before do
          book1 = Book.open(@simple_file, :read_only => true)
          book2 = Book.open(@simple_file, :force_excel => :new)
          book3 = Book.open(@another_simple_file, :force_excel => book2.excel)
          book4 = Book.open(@different_file, :force_excel => :new)
          @excel1 = book1.excel
          @excel2 = book2.excel
          @excel4 = book4.excel
          sheet2 = book2[0]
          @old_cell_value2 = sheet2[1,1].value
          sheet2[1,1] = sheet2[1,1].value == "foo" ? "bar" : "foo"
          sheet3 = book3[0]
          @old_cell_value3 = sheet3[1,1].value
          sheet3[1,1] = sheet3[1,1].value == "foo" ? "bar" : "foo"
        end

        it "should close the first Excel without unsaved workbooks and then raise an error" do
          expect{
            Excel.close_all
          }.to raise_error(ExcelErrorClose, "Excel contains unsaved workbooks")
          @excel1.should_not be_alive
        end

        it "should close the Excel instances without saving the unsaved workbooks" do
          Excel.close_all(:if_unsaved => :forget)
          @excel1.should_not be_alive
          @excel2.should_not be_alive
          @excel4.should_not be_alive
          new_book2 = Book.open(@simple_file)
          new_sheet2 = new_book2[0]
          new_sheet2[1,1].value.should == @old_cell_value2
          new_book2.close   
          new_book3 = Book.open(@another_simple_file)
          new_sheet3 = new_book3[0]
          new_sheet3[1,1].value.should == @old_cell_value3
          new_book3.close   
        end

        it "should close the Excel instances with saving the unsaved workbooks" do
          Excel.close_all(:if_unsaved => :save)
          @excel1.should_not be_alive
          @excel2.should_not be_alive
          @excel4.should_not be_alive
          new_book2 = Book.open(@simple_file)
          new_sheet2 = new_book2[0]
          new_sheet2[1,1].value.should_not == @old_cell_value2
          new_book2.close   
          new_book3 = Book.open(@another_simple_file)
          new_sheet3 = new_book3[0]
          new_sheet3[1,1].value.should_not == @old_cell_value3
          new_book3.close
        end

        it "should raise an error for invalid option" do
          expect {
            Excel.close_all(:if_unsaved => :invalid_option)
          }.to raise_error(ExcelErrorClose, ":if_unsaved: invalid option: :invalid_option") 
        end

        it "should raise an error by default" do
          expect{
            Excel.close_all
          }.to raise_error(ExcelErrorClose, "Excel contains unsaved workbooks")
          @excel1.should_not be_alive
        end
      end

      context "with :if_unsaved => :alert" do
        before do
          @key_sender = IO.popen  'ruby "' + File.join(File.dirname(__FILE__), '/helpers/key_sender.rb') + '" "Microsoft Excel" '  , "w"
          #book1 = Book.open(@simple_file, :read_only => true)
          book2 = Book.open(@simple_file, :force_excel => :new)
          #book3 = Book.open(@another_simple_file, :force_excel => book2.excel)
          #book4 = Book.open(@different_file, :force_excel => :new)
          #@excel1 = book1.excel
          @excel2 = book2.excel
          #@excel4 = book4.excel
          sheet2 = book2[0]
          @old_cell_value2 = sheet2[1,1].value
          sheet2[1,1] = sheet2[1,1].value == "foo" ? "bar" : "foo"
          #sheet3 = book3[0]
          #@old_cell_value3 = sheet3[1,1].value
          #sheet3[1,1] = sheet3[1,1].value == "foo" ? "bar" : "foo"          
        end

        after do
          @key_sender.close
        end


        it "should save if user answers 'yes'" do
          @key_sender.puts "{enter}"
          Excel.close_all(:if_unsaved => :alert)
          #@excel1.should_not be_alive
          @excel2.should_not be_alive
          #@excel4.should_not be_alive
          #@excel5.should_not be_alive
          new_book2 = Book.open(@simple_file)
          new_sheet2 = new_book2[0]
          new_sheet2[1,1].value.should_not == @old_cell_value2
          new_book2.close   
          #new_book3 = Book.open(@another_simple_file)
          #new_sheet3 = new_book3[0]
          #new_sheet3[1,1].value.should == @old_cell_value3
          #new_book3.close       
        end

        it "should not save if user answers 'no'" do            
          @key_sender.puts "{right}{enter}"
          @key_sender.puts "{right}{enter}"
          Excel.close_all(:if_unsaved => :alert)
          #@excel1.should_not be_alive
          @excel2.should_not be_alive
          #@excel4.should_not be_alive
          #@excel5.should_not be_alive
          new_book2 = Book.open(@simple_file)
          new_sheet2 = new_book2[0]
          new_sheet2[1,1].value.should == @old_cell_value2
          new_book2.close   
          #new_book4 = Book.open(@different_file)
          #new_sheet4 = new_book4[0]
          #new_sheet4[1,1].value.should_not == @old_cell_value4
          #new_book4.close   
        end

      #  it "should not save if user answers 'cancel'" do
      #    @key_sender.puts "{left}{enter}"
      #    @key_sender.puts "{left}{enter}"
      #    @key_sender.puts "{left}{enter}"
      #    @key_sender.puts "{left}{enter}"
      #    expect{
      #      Excel.close_all(:if_unsaved => :alert)
      #      }.to raise_error(ExcelUserCanceled, "close: canceled by user")
      #  end
      end
    end

    describe "close" do

      context "with a saved workbook" do

        before do
          @excel = Excel.create
          @book = Book.open(@simple_file)
        end

        it "should close the Excel" do
          @excel.should be_alive
          @book.should be_alive
          @excel.close
          @excel.should_not be_alive
          @book.should_not be_alive
        end
      end

      context "with unsaved workbooks" do

        before do
          @excel = Excel.create
          @book = Book.open(@simple_file)
          sheet = @book[0]
          @old_cell_value = sheet[1,1].value
          sheet[1,1] = sheet[1,1].value == "foo" ? "bar" : "foo"
          @book2 = Book.open(@another_simple_file)
          sheet2 = @book2[0]
          @old_cell_value2 = sheet2[1,1].value
          sheet2[1,1] = sheet2[1,1].value == "foo" ? "bar" : "foo"
        end

        it "should raise an error" do
          @excel.should be_alive
          @book.should be_alive
          @book.saved.should be_false
          @book2.should be_alive
          @book2.saved.should be_false
          expect{
            @excel.close(:if_unsaved => :raise)
          }.to raise_error(ExcelErrorClose, "Excel contains unsaved workbooks")
        end

        it "should close the Excel without saving the workbook" do
          @excel.should be_alive
          @excel.close(:if_unsaved => :forget)
          @excel.should_not be_alive
          new_book = Book.open(@simple_file)
          new_sheet = new_book[0]
          new_sheet[1,1].value.should == @old_cell_value
          new_book.close          
          new_book2 = Book.open(@another_simple_file)
          new_sheet2 = new_book2[0]
          new_sheet2[1,1].value.should == @old_cell_value2
          new_book2.close 
        end

        it "should close the Excel with saving the workbook" do
          @excel.should be_alive
          @excel.close(:if_unsaved => :save)
          @excel.should_not be_alive
          new_book = Book.open(@simple_file)
          new_sheet = new_book[0]
          new_sheet[1,1].value.should_not == @old_cell_value
          new_book.close          
          new_book2 = Book.open(@another_simple_file)
          new_sheet2 = new_book2[0]
          new_sheet2[1,1].value.should_not == @old_cell_value2
          new_book2.close   
        end

        it "should raise an error for invalid option" do
          expect {
            @excel.close(:if_unsaved => :invalid_option)
          }.to raise_error(ExcelErrorClose, ":if_unsaved: invalid option: :invalid_option") 
        end

        it "should raise an error by default" do
          @excel.should be_alive
          expect{
            @excel.close
          }.to raise_error(ExcelErrorClose, "Excel contains unsaved workbooks")
        end
  
        it "should close the Excel without saving the workbook hard" do
          @excel.should be_alive
          @book.should be_alive
          @book.saved.should be_false
          @excel.close(:if_unsaved => :forget, :hard => true)
          @excel.should_not be_alive
          @book.should_not be_alive
          new_book = Book.open(@simple_file)
          new_sheet = new_book[0]
          new_sheet[1,1].value.should == @old_cell_value
          new_book.close    
          new_book.excel.close(:hard => true)
          procs = WIN32OLE.connect("winmgmts:\\\\.")
          processes = procs.InstancesOf("win32_process")     
          result = []
          processes.each do |p|
            result << p if p.name == "EXCEL.EXE"
          end
          result.should be_empty
        end
      end

      context "with :if_unsaved => :alert" do

        before do
          @key_sender = IO.popen  'ruby "' + File.join(File.dirname(__FILE__), '/helpers/key_sender.rb') + '" "Microsoft Excel" '  , "w"
          @excel = Excel.create
          @book = Book.open(@simple_file)
          sheet = @book[0]
          @old_cell_value = sheet[1,1].value
          sheet[1,1] = sheet[1,1].value == "foo" ? "bar" : "foo"
        end

        after do
          @key_sender.close
        end

        it "should save if user answers 'yes'" do
          # "Yes" is to the left of "No", which is the  default. --> language independent
          @excel.should be_alive
          @key_sender.puts "{enter}" 
          @excel.close(:if_unsaved => :alert)
          @excel.should_not be_alive
          new_book = Book.open(@simple_file)
          new_sheet = new_book[0]
          new_sheet[1,1].value.should_not == @old_cell_value
          new_book.close   
        end

        it "should not save if user answers 'no'" do            
          @excel.should be_alive
          @book.should be_alive
          @book.saved.should be_false
          @key_sender.puts "{right}{enter}"
          @excel.close(:if_unsaved => :alert)
          @excel.should_not be_alive
          @book.should_not be_alive
          new_book = Book.open(@simple_file)
          new_sheet = new_book[0]
          new_sheet[1,1].value.should == @old_cell_value
          new_book.close     
        end

        it "should not save if user answers 'cancel'" do
          # strangely, in the "cancel" case, the question will sometimes be repeated twice            
          @excel.should be_alive
          @book.should be_alive
          @book.saved.should be_false
          @key_sender.puts "{left}{enter}"
          @key_sender.puts "{left}{enter}"
          expect{
            @excel.close(:if_unsaved => :alert)
            }.to raise_error(ExcelUserCanceled, "close: canceled by user")
        end
      end
    end

    describe "alive" do

      it "should yield alive" do
        excel = Excel.create
        excel.alive?.should be_true
      end

      it "should yield not alive" do
        excel = Excel.create
        excel.close
        excel.alive?.should be_false
      end

    end

    describe "==" do
      before do
        @excel1 = Excel.create
      end

      it "should be true with two identical excel instances" do
        excel2 = Excel.current
        excel2.should == @excel1
      end

      it "should be false with two different excel instances" do
        excel2 = Excel.create
        excel2.should_not == @excel1
      end

      it "should be false with non-Excel objects" do
        @excel1.should_not == "hallo"
        @excel1.should_not == 7
        @excel1.should_not == nil
      end

      it "should be false with dead Excel objects" do
        excel2 = Excel.current
        Excel.close_all
        excel2.should_not == @excel1
      end

    end

    context "with Visible and DisplayAlerts" do

      it "should create Excel visible" do
        excel = Excel.new(:visible => true)
        excel.Visible.should be_true
        excel.visible.should be_true
        excel.DisplayAlerts.should be_false
        excel.displayalerts.should be_false
        excel.visible = false
        excel.Visible.should be_false
        excel.visible.should be_false
      end

      it "should create Excel with DispayAlerts enabled" do        
        excel = Excel.new(:displayalerts => true)
        excel.DisplayAlerts.should be_true
        excel.displayalerts.should be_true
        excel.Visible.should be_false
        excel.visible.should be_false
        excel.displayalerts = false
        excel.DisplayAlerts.should be_false
        excel.displayalerts.should be_false
      end

      it "should keep visible and displayalerts values when reusing Excel" do
        excel = Excel.new(:visible => true)
        excel.visible.should be_true
        excel.displayalerts.should be_false
        excel2 = Excel.new(:displayalerts => true)
        excel2.should == excel
        excel.visible.should be_true
        excel.displayalerts.should be_true        
      end

      it "should keep displayalerts and visible values when reusing Excel" do
        excel = Excel.new(:displayalerts => true)
        excel.visible.should be_false
        excel.displayalerts.should be_true
        excel2 = Excel.new(:visible => true)
        excel2.should == excel
        excel.visible.should be_true
        excel.displayalerts.should be_true        
      end

    end

    context "with displayalerts" do
      before do
        @excel1 = Excel.new(:displayalerts => true)
        @excel2 = Excel.new(:displayalerts => false, :reuse => false)
      end

      it "should turn off displayalerts" do
        @excel1.DisplayAlerts.should be_true
        begin
          @excel1.with_displayalerts false do
            @excel1.DisplayAlerts.should be_false
            raise TestError, "any_error"
          end
        rescue TestError
          @excel1.DisplayAlerts.should be_true
        end
      end
    
      it "should turn on displayalerts" do
        @excel2.DisplayAlerts.should be_false
        begin
          @excel1.with_displayalerts true do
            @excel1.DisplayAlerts.should be_true
            raise TestError, "any_error"
          end
        rescue TestError
          @excel2.DisplayAlerts.should be_false
        end
      end

    end

    context "method delegation for capitalized methods" do
      before do
        @excel1 = Excel.new
      end

      it "should raise WIN32OLERuntimeError" do
        expect{ @excel1.NonexistingMethod }.to raise_error(VBAMethodMissingError, /unknown VBA property or method :NonexistingMethod/)
      end

      it "should raise NoMethodError for uncapitalized methods" do
        expect{ @excel1.nonexisting_method }.to raise_error(NoMethodError)
      end

      it "should report that Excel is not alive" do
        @excel1.close
        expect{ @excel1.Nonexisting_method }.to raise_error(ExcelError, "method missing: Excel not alive")
      end

    end

    context "with hwnd and hwnd2excel" do
      
      before do
        @excel1 = Excel.new
        @excel2 = Excel.new(:reuse => false)
      end

      it "should yield the correct hwnd" do
        @excel1.Hwnd.should == @excel1.hwnd
        @excel2.Hwnd.should == @excel2.hwnd
      end

      it "should provide the same excel instances" do
        @excel1.should_not == @excel2
        excel3 = Excel.hwnd2excel(@excel1.hwnd)
        excel4 = Excel.hwnd2excel(@excel2.hwnd)
        @excel1.should == excel3
        @excel2.should == excel4
        excel3.should_not == excel4 
      end
    end

    describe "unsaved_workbooks" do

      context "with standard" do
        
        before do
          @book = Book.open(@simple_file)
          @book2 = Book.open(@another_simple_file)
          @book3 = Book.open(@different_file, :read_only => true)
          sheet = @book[0]
          sheet[1,1] = sheet[1,1].value == "foo" ? "bar" : "foo"
          sheet3 = @book3[0]
          sheet3[1,1] = sheet3[1,1].value == "foo" ? "bar" : "foo"
        end

        it "should list unsaved workbooks" do
          @book.Saved.should be_false
          @book2.Save
          @book2.Saved.should be_true
          @book3.Saved.should be_false
          excel = @book.excel
          # unsaved_workbooks yields different WIN32OLE objects than book.workbook
          uw_names = []
          excel.unsaved_workbooks.each {|uw| uw_names << uw.Name}
          uw_names.should == [@book.workbook.Name]
        end

      end
    end

    describe "generate workbook" do

      context "with standard" do
        
        before do
          @excel1 = Excel.create
          @file_name = @dir + '/bar.xls'
        end

        it "should generate a workbook" do
          workbook = @excel1.generate_workbook(@file_name)
          workbook.should be_a WIN32OLE
          workbook.Name.should == File.basename(@file_name)
          workbook.FullName.should == RobustExcelOle::absolute_path(@file_name)
          workbook.Saved.should be_true
          workbook.ReadOnly.should be_false
          workbook.Sheets.Count.should == 3
          workbooks = @excel1.Workbooks
          workbooks.Count.should == 1
        end

        it "should generate the same workbook twice" do
          workbook = @excel1.generate_workbook(@file_name)
          workbook.should be_a WIN32OLE
          workbook.Name.should == File.basename(@file_name)
          workbook.FullName.should == RobustExcelOle::absolute_path(@file_name)
          workbook.Saved.should be_true
          workbook.ReadOnly.should be_false
          workbook.Sheets.Count.should == 3
          workbooks = @excel1.Workbooks
          workbooks.Count.should == 1
          workbook2 = @excel1.generate_workbook(@file_name)
          workbook2.should be_a WIN32OLE
          workbooks = @excel1.Workbooks
          workbooks.Count.should == 2
        end

        it "should generate a workbook if one is already existing" do
          book = Book.open(@simple_file)
          workbook = @excel1.generate_workbook(@file_name)
          workbook.should be_a WIN32OLE
          workbook.Name.should == File.basename(@file_name)
          workbook.FullName.should == RobustExcelOle::absolute_path(@file_name)
          workbook.Saved.should be_true
          workbook.ReadOnly.should be_false
          workbook.Sheets.Count.should == 3
          workbooks = @excel1.Workbooks
          workbooks.Count.should == 2
        end

        it "should raise error when book cannot be saved" do
          expect{
            workbook = @excel1.generate_workbook(@invalid_name_file)
          # not always Unknown ???? ToDo #*#
          #}.to raise_error(ExcelErrorSaveUnknown)
          }.to raise_error(ExcelErrorSave)
        end

      end
    end
  end
end

class TestError < RuntimeError  # :nodoc: #
end
