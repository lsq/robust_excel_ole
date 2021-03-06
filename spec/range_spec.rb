# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), './spec_helper')

include RobustExcelOle

describe RobustExcelOle::Range do

  before(:all) do
    excel = Excel.new(:reuse => true)
    open_books = excel == nil ? 0 : excel.Workbooks.Count
    puts "*** open books *** : #{open_books}" if open_books > 0
    Excel.kill_all
  end

  before do
    @dir = create_tmpdir
    @book = Workbook.open(@dir + '/workbook.xls', :force_excel => :new)
    @sheet = @book.sheet(2)
    @range = RobustExcelOle::Range.new(@sheet.ole_worksheet.UsedRange.Rows(1))
  end

  after do
    @book.close
    Excel.kill_all
    rm_tmp(@dir)
  end

  describe "#each" do
    it "items is RobustExcelOle::Cell" do
      @range.each do |cell|
        cell.should be_kind_of RobustExcelOle::Cell
      end
    end
  end

  describe "#values" do
    context "with (0..2)" do
      it { @range.values(0..2).should eq ['simple', 'file', 'sheet2'] }
    end

    context "with (1..2)" do
      it { @range.values(1..2).should eq ['file', 'sheet2'] }
    end

    context "with (2..2)" do
      it { @range.values(2..2).should eq ['sheet2'] }
    end

    context "with no arguments" do
      it { @range.values.should eq ['simple', 'file', 'sheet2'] }
    end

    context "when instance is column range" do
      before do
        @sheet = @book.sheet(1)
        @range = RobustExcelOle::Range.new(@sheet.ole_worksheet.UsedRange.Columns(1))
      end
      it { @range.values.should eq ['foo', 'foo', 'matz'] }
    end

    context "read 'merge_cells.xls'" do
      before do
        @merge_cells_book = Workbook.open("#{@dir}/merge_cells.xls", :force_excel => :new)
        @merge_cells_sheet = @merge_cells_book.sheet(1)
      end

      after do
        @merge_cells_book.close
      end

      context "only merged_cell" do
        before do
          @only_merged_range = @merge_cells_sheet.row_range(4)
        end

        context "without argument" do
          it { @only_merged_range.values.should eq ['merged', 'merged', 'merged', 'merged'] }
        end

        context "with (1..2)" do
          it { @only_merged_range.values(2..3).should eq ['merged', 'merged'] }
        end

      end

      context "mix merged cell and no merge cell" do
        before do
          @mix_merged_no_merged_range = @merge_cells_sheet.row_range(2)
        end

        context "without argument" do
          it { @mix_merged_no_merged_range.values.should eq ['first merged', 'first merged', 'first merged', nil] }
        end

        context "with (2..3)" do
          it { @mix_merged_no_merged_range.values(2..3).should eq ['first merged', nil] }
        end

      end
    end
  end

  describe "#[]" do
    context "access [0]" do
      it { @range[0].should be_kind_of RobustExcelOle::Cell }
      it { @range[0].Value.should eq 'simple' }
    end

    context "access [2]" do
      it { @range[2].Value.should eq 'sheet2' }
    end

    context "access [0] and [1] and [2]" do
      it "should get every values" do
        @range[0].Value.should eq 'simple'
        @range[1].Value.should eq 'file'
        @range[2].Value.should eq 'sheet2'
      end
    end
  end

  describe "#v" do

    context "v" do

      it "should return value" do
        @sheet[1,1].v.should == 'simple'
        @sheet.range(1..2,3..4).v.should == [["sheet2", nil], [nil, nil]] 
      end 
    end

  end

  describe "#copy" do
    
    before do
      @book1 = Workbook.open(@dir + '/workbook.xls')
      @sheet1 = @book1.sheet(1)
      @range1 = @sheet1.range([1..2,1..3])
      @sheet1[1,1].Interior.ColorIndex = 4
      @book2 = Workbook.open(@dir + '/different_workbook.xls')
      @sheet2 = @book2.sheet(2)
      @book3 = Workbook.open(@dir + '/another_workbook.xls', :force => {:excel => :new})
      @sheet3 = @book3.sheet(3)
    end

    after do
      @book1.close(:if_unsaved => :forget)
      @book2.close(:if_unsaved => :forget)
      @book3.close(:if_unsaved => :forget)
    end

    it "should copy range" do
      @range1.copy([4,2])
      @sheet1.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy range when giving an address" do
      @range1.copy([4..5,2..4])
      @sheet1.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy range to another worksheet of another workbook" do
      @range1.copy([4,2], @sheet2)
      @sheet2.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet2[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy range to another worksheet of another workbook of another Excel instance" do
      @range1.copy([4,2], @sheet3)
      @sheet3.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy values only" do
      @range1.copy([4,2], @sheet1, :values_only => true)
      @sheet1.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy values only to another worksheet of another Excel instance" do
      @range1.copy([4,2], @sheet3, :values_only => true)
      @sheet3.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy and transpose with values only" do
      @range1.copy([4,2], @sheet1, :values_only => true, :transpose => true)
      @sheet1.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy and transpose with values only into another Excel instance" do
      @range1.copy([4,2], @sheet3, :values_only => true, :transpose => true)
      @sheet3.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy and transpose" do
      @range1.copy([4,2], @sheet1, :transpose => true)
      @sheet1.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy and transpose into another Excel instance" do
      @range1.copy([4,2], @sheet3, :transpose => true)
      @sheet3.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == 4
    end
  end

  describe "#copy with deprecated interface" do

    before do
      @book1 = Workbook.open(@dir + '/workbook.xls')
      @sheet1 = @book1.sheet(1)
      @range1 = @sheet1.range([1..2,1..3])
      @sheet1[1,1].Interior.ColorIndex = 4
      @book2 = Workbook.open(@dir + '/different_workbook.xls')
      @sheet2 = @book2.sheet(2)
      @book3 = Workbook.open(@dir + '/another_workbook.xls', :force => {:excel => :new})
      @sheet3 = @book3.sheet(3)
    end

    after do
      @book1.close(:if_unsaved => :forget)
      @book2.close(:if_unsaved => :forget)
      @book3.close(:if_unsaved => :forget)
    end

    it "should copy range" do
      @range1.copy(4,2)
      @sheet1.range(4..5,2..4).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy range when giving an address" do
      @range1.copy(4..5,2..4)
      @sheet1.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy range to another worksheet of another workbook" do
      @range1.copy(4,2, @sheet2)
      @sheet2.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet2[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy range to another worksheet of another workbook of another Excel instance" do
      @range1.copy(4,2, @sheet3)
      @sheet3.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy values only" do
      @range1.copy(4,2, @sheet1, :values_only => true)
      @sheet1.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy values only to another worksheet of another Excel instance" do
      @range1.copy(4,2, @sheet3, :values_only => true)
      @sheet3.range([4..5,2..4]).Value.should == [["foo", "workbook", "sheet1"],["foo", nil, "foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy and transpose with values only" do
      @range1.copy(4,2, @sheet1, :values_only => true, :transpose => true)
      @sheet1.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy and transpose with values only into another Excel instance" do
      @range1.copy(4,2, @sheet3, :values_only => true, :transpose => true)
      @sheet3.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == -4142
    end

    it "should copy and transpose" do
      @range1.copy(4,2, @sheet1, :transpose => true)
      @sheet1.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet1[4,2].Interior.ColorIndex.should == 4
    end

    it "should copy and transpose into another Excel instance" do
      @range1.copy(4,2, @sheet3, :transpose => true)
      @sheet3.range([4..6,2..3]).Value.should == [["foo", "foo"],["workbook", nil],["sheet1","foobaaa"]]
      @sheet3[4,2].Interior.ColorIndex.should == 4
    end

  end

  describe "#method_missing" do
    it "can access COM method" do
      @range.Range(@range.Cells.Item(1), @range.Cells.Item(3)).Value.should eq [@range.values(0..2)]
    end

    context "unknown method" do
      it { expect { @range.hogehogefoo}.to raise_error }
    end
  end
end
