# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), './spec_helper')



$VERBOSE = nil

describe RobustExcelOle::Book do
  before do
    @dir = create_tmpdir
    @simple_file = @dir + '/simple.xls'
    @simple_save = @dir + '/simple_save.xls'
  end

  after do
    rm_tmp(@dir)
  end

  context "class methods" do
    context "create file" do
      it "simple file with default" do
        expect {
          @book = RobustExcelOle::Book.new(@simple_file)
          }.to_not raise_error
        @book.should be_a RobustExcelOle::Book
        @book.close
      end
    end
  end

  describe "open" do

    after do
      RobustExcelOle::ExcelApp.close_all
    end

    context "with non-existing file" do
      it "should raise an exception" do
        File.delete @simple_save rescue nil
        expect {
          RobustExcelOle::Book.open(@simple_save)
        }.to raise_error(ExcelErrorOpen, "file #{@simple_save} not found")
      end
    end

    context "with standard options" do
      before do
        @book = RobustExcelOle::Book.open(@simple_file)
      end

      after do
        @book.close
      end

      it "should say that it lives" do
        @book.alive?.should be_true
      end      
    end

    context "with excel_app" do
      before do
        @new_book = RobustExcelOle::Book.open(@simple_file)
      end
      after do
        @new_book.close
      end
      it "should provide the excel application of the book" do
        excel_app = @new_book.excel_app
        excel_app.class.should == RobustExcelOle::ExcelApp
        excel_app.should be_a RobustExcelOle::ExcelApp
      end
    end

    context "with :read_only" do
      it "should be able to save, if :read_only => false" do
        book = RobustExcelOle::Book.open(@simple_file, :read_only => false)
        book.should be_a RobustExcelOle::Book
        expect {
          book.save(@simple_save, :if_exists => :overwrite)
        }.to_not raise_error
        book.close
      end

      it "should be able to save, if :read_only is set to default value" do
        book = RobustExcelOle::Book.open(@simple_file)
        book.should be_a RobustExcelOle::Book
        expect {
          book.save(@simple_save, :if_exists => :overwrite)
        }.to_not raise_error
        book.close
      end

      it "should raise an error, if :read_only => true" do
        book = RobustExcelOle::Book.open(@simple_file, :read_only => true)
        book.should be_a RobustExcelOle::Book
        expect {
          book.save(@simple_save, :if_exists => :overwrite)
        }.to raise_error
        book.close
      end
    end

    context "with block" do
      it 'block parameter should be instance of RobustExcelOle::Book' do
        RobustExcelOle::Book.open(@simple_file) do |book|
          book.should be_a RobustExcelOle::Book
        end
      end
    end

    context "with WIN32OLE#GetAbsolutePathName" do
      it "'~' should be HOME directory" do
        path = '~/Abrakadabra.xlsx'
        expected_path = Regexp.new(File.expand_path(path).gsub(/\//, "."))
        expect {
          RobustExcelOle::Book.open(path)
        }.to raise_error(ExcelErrorOpen, "file #{path} not found")
      end
    end

    context "with ==" do

      before do
        @book = RobustExcelOle::Book.open(@simple_file)
      end

      after do
        @book.close
        @new_book.close rescue nil
      end

      it "should be true with two identical books" do
        @new_book = RobustExcelOle::Book.open(@simple_file)
        @new_book.should == @book
      end

      it "should be false with two different books" do
        different_file = @dir + '/different_simple.xls'
        @new_book = RobustExcelOle::Book.new(different_file)
        @new_book.should_not == @book
      end

      it "should be false with same book names but different paths" do
        simple_file_different_path = @dir + '/more_data/simple.xls'
        @new_book = RobustExcelOle::Book.new(simple_file_different_path, :reuse => false)
        @new_book.should_not == @book
      end

      it "should be false with same book names but different excel apps" do
        @new_book = RobustExcelOle::Book.new(@simple_file, :reuse => false)
        @new_book.should_not == @book
      end

      it "should be false with non-Books" do
        @book.should_not == "hallo"
        @book.should_not == 7
        @book.should_not == nil
      end
    end

    context "with an already opened book" do

      before do
        @book = RobustExcelOle::Book.open(@simple_file)
      end

      after do
        @book.close
      end

      context "with an already saved book" do
        possible_options = [:raise, :accept, :forget, nil]
        possible_options.each do |options_value|        
          context "with in the same directory and :if_unsaved => #{options_value}" do
            before do
              @new_book = RobustExcelOle::Book.open(@simple_file, :reuse=> true, :if_unsaved => options_value)
            end
            after do
              @new_book.close
            end
            it "should open without problems " do
                @new_book.should be_a RobustExcelOle::Book
            end
            it "should belong to the same Excel application" do
              @new_book.excel_app.should == @book.excel_app
            end
          end
        end
      end

      context "with an unsaved book" do

        before do
          @sheet = @book[0]
          @book.add_sheet(@sheet, :as => 'copyed_name')
        end

        after do
          @new_book.close rescue nil
        end

        it "should raise an error, if if_unsaved is :raise" do
          expect {
            @new_book = RobustExcelOle::Book.open(@simple_file, :if_unsaved => :raise)
          }.to raise_error(ExcelErrorOpen, "book is already open but not saved (#{File.basename(@simple_file)})")
        end

        it "should let the book open, if if_unsaved is :accept" do
          expect {
            @new_book = RobustExcelOle::Book.open(@simple_file, :if_unsaved => :accept)
            }.to_not raise_error
          @book.alive?.should be_true
          @new_book.alive?.should be_true
          @new_book.filename.should == @book.filename
        end

        it "should open book and close old book, if if_unsaved is :forget" do
          @new_book = RobustExcelOle::Book.open(@simple_file, :if_unsaved => :forget)
          @book.alive?.should be_false
          @new_book.alive?.should be_true
          @new_book.filename.downcase.should == @simple_file.downcase
        end
      end
    end
  end

  describe "save" do
    context "when open with read only" do
      before do
        @book = RobustExcelOle::Book.open(@simple_file, :read_only => true)
      end

      it {
        expect {
          @book.save
        }.to raise_error(IOError,
                     "Not opened for writing(open with :read_only option)")
      }
    end

    context "with argument" do
      before do
        RobustExcelOle::Book.open(@simple_file) do |book|
          book.save(@simple_save, :if_exists => :overwrite)
        end
      end

      it "should save to 'simple_save.xlsx'" do
        File.exist?(@simple_save).should be_true
      end
    end

    context "with different extensions" do
      before do
        @book = RobustExcelOle::Book.open(@simple_file)
      end

      after do
        @book.close
      end

      possible_extensions = ['xls', 'xlsm', 'xlsx']
      possible_extensions.each do |extensions_value|
        it "should save to 'simple_save.#{extensions_value}'" do
          simple_save = @dir + '/simple_save.' + extensions_value
          File.delete simple_save rescue nil
          @book.save(simple_save, :if_exists => :overwrite)
          File.exist?(simple_save).should be_true
          new_book = RobustExcelOle::Book.open(simple_save)
          new_book.should be_a RobustExcelOle::Book
          new_book.close
        end
      end
    end

    # options :overwrite, :raise, :excel, no option, invalid option
    possible_displayalerts = [true, false]
    possible_displayalerts.each do |displayalert_value|
      context "with displayalerts=#{displayalert_value}" do
        before do
          @book = RobustExcelOle::Book.open(@simple_file, :displayalerts => displayalert_value)
        end

        after do
          @book.close
        end

        it "should save to simple_save.xls with :if_exists => :overwrite" do
          File.delete @simple_save rescue nil
          File.open(@simple_save,"w") do | file |
            file.puts "garbage"
          end
          @book.save(@simple_save, :if_exists => :overwrite)
          File.exist?(@simple_save).should be_true
          new_book = RobustExcelOle::Book.open(@simple_save)
          new_book.should be_a RobustExcelOle::Book
          new_book.close
        end

        it "should save to 'simple_save.xls' with :if_exists => :raise" do
          dirname, basename = File.split(@simple_save)
          File.delete @simple_save rescue nil
          File.open(@simple_save,"w") do | file |
            file.puts "garbage"
          end
          File.exist?(@simple_save).should be_true
          booklength = File.size?(@simple_save)
          expect {
            @book.save(@simple_save, :if_exists => :raise)
            }.to raise_error(ExcelErrorSave, 'book already exists: ' + basename)
          File.exist?(@simple_save).should be_true
          (File.size?(@simple_save) == booklength).should be_true
        end

        context "with :if_exists => :excel" do
          before do
            File.delete @simple_save rescue nil
            File.open(@simple_save,"w") do | file |
              file.puts "garbage"
            end
            @garbage_length = File.size?(@simple_save)
            @key_sender = IO.popen  'ruby "' + File.join(File.dirname(__FILE__), '/helpers/key_sender.rb') + '" "Microsoft Excel" '  , "w"
          end

          after do
            @key_sender.close
          end

          it "should save if user answers 'yes'" do
            # "Yes" is to the left of "No", which is the  default. --> language independent
            @key_sender.puts "{left}{enter}" #, :initial_wait => 0.2, :if_target_missing=>"Excel window not found")
            @book.save(@simple_save, :if_exists => :excel)
            File.exist?(@simple_save).should be_true
            File.size?(@simple_save).should > @garbage_length
            new_book = RobustExcelOle::Book.open(@simple_save)
            new_book.should be_a RobustExcelOle::Book
            @book.excel_app.DisplayAlerts.should == displayalert_value
            new_book.close
          end

          it "should not save if user answers 'no'" do
            # Just give the "Enter" key, because "No" is the default. --> language independent
            # strangely, in the "no" case, the question will sometimes be repeated three times
            @key_sender.puts "{enter}"
            @key_sender.puts "{enter}"
            @key_sender.puts "{enter}"
            #@key_sender.puts "%{n}" #, :initial_wait => 0.2, :if_target_missing=>"Excel window not found")
            @book.save(@simple_save, :if_exists => :excel)
            File.exist?(@simple_save).should be_true
            File.size?(@simple_save).should == @garbage_length
          end 

          it "should report save errors" do
            #@key_sender.puts "{left}{enter}" #, :initial_wait => 0.2, :if_target_missing=>"Excel window not found")
            @book.workbook.Close
            expect{
              @book.save(@simple_save, :if_exists => :excel)
              }.to raise_error(ExcelErrorSaveUnknown)
            File.exist?(@simple_save).should be_true
            File.size?(@simple_save).should == @garbage_length
            @book.excel_app.DisplayAlerts.should == displayalert_value
          end


        end

        it "should save to 'simple_save.xls' with :if_exists => nil" do
          dirname, basename = File.split(@simple_save)
          File.delete @simple_save rescue nil
          File.open(@simple_save,"w") do | file |
            file.puts "garbage"
          end
          File.exist?(@simple_save).should be_true
          booklength = File.size?(@simple_save)
          expect {
            @book.save(@simple_save)
            }.to raise_error(ExcelErrorSave, 'book already exists: ' + basename)
          File.exist?(@simple_save).should be_true
          (File.size?(@simple_save) == booklength).should be_true
        end

        it "should save to 'simple_save.xls' with :if_exists => :invalid_option" do
          File.delete @simple_save rescue nil
          @book.save(@simple_save)
          expect {
            @book.save(@simple_save, :if_exists => :invalid_option)
            }.to raise_error(ExcelErrorSave, 'invalid option (invalid_option)')
        end
      end
    end
  end

  describe "#add_sheet" do
    before do
      @book = RobustExcelOle::Book.open(@simple_file)
      @sheet = @book[0]
    end

    after do
      @book.close
    end
    
    context "only first argument" do
      it "should add worksheet" do
        expect { @book.add_sheet @sheet }.to change{ @book.workbook.Worksheets.Count }.from(3).to(4)
      end

      it "should return copyed sheet" do
        sheet = @book.add_sheet @sheet
        copyed_sheet = @book.workbook.Worksheets.Item(@book.workbook.Worksheets.Count)
        sheet.name.should eq copyed_sheet.name
      end
    end

    context "with first argument" do
      context "with second argument is {:as => 'copyed_name'}" do
        it "copyed sheet name should be 'copyed_name'" do
          @book.add_sheet(@sheet, :as => 'copyed_name').name.should eq 'copyed_name'
        end
      end

      context "with second argument is {:before => @sheet}" do
        it "should add the first sheet" do
          @book.add_sheet(@sheet, :before => @sheet).name.should eq @book[0].name
        end
      end

      context "with second argument is {:after => @sheet}" do
        it "should add the first sheet" do
          @book.add_sheet(@sheet, :after => @sheet).name.should eq @book[1].name
        end
      end

      context "with second argument is {:before => @book[2], :after => @sheet}" do
        it "should arguments in the first is given priority" do
          @book.add_sheet(@sheet, :before => @book[2], :after => @sheet).name.should eq @book[2].name
        end
      end

    end

    context "without first argument" do
      context "second argument is {:as => 'new sheet'}" do
        it "should return new sheet" do
          @book.add_sheet(:as => 'new sheet').name.should eq 'new sheet'
        end
      end

      context "second argument is {:before => @sheet}" do
        it "should add the first sheet" do
          @book.add_sheet(:before => @sheet).name.should eq @book[0].name
        end
      end

      context "second argument is {:after => @sheet}" do
        it "should add the second sheet" do
          @book.add_sheet(:after => @sheet).name.should eq @book[1].name
        end
      end

    end

    context "without argument" do
      it "should add empty sheet" do
        expect { @book.add_sheet }.to change{ @book.workbook.Worksheets.Count }.from(3).to(4)
      end

      it "should return copyed sheet" do
        sheet = @book.add_sheet
        copyed_sheet = @book.workbook.Worksheets.Item(@book.workbook.Worksheets.Count)
        sheet.name.should eq copyed_sheet.name
      end
    end
  end

  describe 'access sheet' do
    before do
      @book = RobustExcelOle::Book.open(@simple_file)
    end

    after do
      @book.close
    end

    it 'with sheet name' do
      @book['Sheet1'].should be_kind_of RobustExcelOle::Sheet
    end

    it 'with integer' do
      @book[0].should be_kind_of RobustExcelOle::Sheet
    end

    it 'with block' do
      @book.each do |sheet|
        sheet.should be_kind_of RobustExcelOle::Sheet
      end
    end

    context 'open with block' do
      it {
        RobustExcelOle::Book.open(@simple_file) do |book|
          book['Sheet1'].should be_a RobustExcelOle::Sheet
        end
      }
    end
  end

end
