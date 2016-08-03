# -*- coding: utf-8 -*-

require 'timeout'

def ka 
  Excel.kill_all
end


module RobustExcelOle      

  class Excel < REOCommon    

    attr_accessor :ole_excel
    attr_accessor :visible
    attr_accessor :displayalerts

    alias ole_object ole_excel

    @@hwnd2excel = {}    

    # creates a new Excel instance
    # @param [Hash] options the options
    # @option options [Variant] :displayalerts 
    # @option options [Boolean] :visible 
    # @return [Excel] a new Excel instance
    def self.create(options = {})
      new(options.merge({:reuse => false}))
    end

    # returns (connects to) the current (first opened) Excel instance, if such a running Excel instance exists    
    # returns a new Excel instance, otherwise
    # @option options [Variant] :displayalerts 
    # @option options [Boolean] :visible 
    # @return [Excel] an Excel instance
    def self.current(options = {})
      new(options.merge({:reuse => true}))
    end

    # returns an Excel instance  
    # given a WIN32OLE object representing an Excel instance, or a Hash representing options
    # @param [Hash] options the options
    # @option options [Boolean] :reuse      
    # @option options [Boolean] :visible
    # @option options [Variant] :displayalerts  
    # options: 
    #  :reuse          connects to an already running Excel instance (true) or
    #                  creates a new Excel instance (false)  (default: true)
    #  :visible        makes the Excel visible               (default: false)
    #  :displayalerts  enables or disables DisplayAlerts     (true, false, :if_visible (default))   
    # @return [Excel] an Excel instance
    def self.new(options = {})
      if options.is_a? WIN32OLE
        ole_xl = options
      else
        options = {:reuse => true}.merge(options)
        if options[:reuse] == true then
          ole_xl = current_excel
        end
      end
      if not (ole_xl)
        ole_xl = WIN32OLE.new('Excel.Application')
        options = {
          :displayalerts => :if_visible,
          :visible => false,
        }.merge(options)
      end
      hwnd = ole_xl.HWnd
      stored = hwnd2excel(hwnd)
      if stored 
        result = stored
      else
        result = super(options)
        result.instance_variable_set(:@ole_excel, ole_xl)        
        WIN32OLE.const_load(ole_xl, RobustExcelOle) unless RobustExcelOle.const_defined?(:CONSTANTS)
        @@hwnd2excel[hwnd] = WeakRef.new(result)
      end
      unless options.is_a? WIN32OLE
        reused = options[:reuse] && (not stored.nil?)
        visible_value = (reused && options[:visible].nil?) ? result.visible : options[:visible]
        displayalerts_value = (reused && options[:displayalerts].nil?) ? result.displayalerts : options[:displayalerts]
        ole_xl.Visible = visible_value
        ole_xl.DisplayAlerts = (displayalerts_value == :if_visible) ? visible_value : displayalerts_value
        result.instance_variable_set(:@visible, visible_value)
        result.instance_variable_set(:@displayalerts, displayalerts_value)
      end
      result
    end

    def initialize(options= {}) # :nodoc: #
      @excel = self
    end

    # reopens a closed Excel instance
    # @param [Hash] opts the options
    # @option opts [Boolean] :reopen_workbooks
    # @option opts [Boolean] :displayalerts
    # @option opts [Boolean] :visible
    # options: reopen_workbooks (default: false): reopen the workbooks in the Excel instances
    #          :visible (default: false), :displayalerts (default: :if_visible)
    # @return [Excel] an Excel instance
    def recreate(opts = {})      
      unless self.alive?
        opts = {
          :visible => @visible ? @visible : false,
          :displayalerts => @displayalerts ? @displayalerts : :if_visible          
        }.merge(opts)
        @ole_excel = WIN32OLE.new('Excel.Application')
        self.visible = opts[:visible]
        self.displayalerts = opts[:displayalerts]        
        if opts[:reopen_workbooks]
          books = book_class.books
          books.each do |book|
            book.reopen if ((not book.alive?) && book.excel.alive? && book.excel == self)
          end        
        end
      end
      self 
    end

  private
    
    # returns a Win32OLE object that represents a Excel instance to which Excel connects
    # connects to the first opened Excel instance
    # if this Excel instance is being closed, then Excel creates a new Excel instance
    def self.current_excel   # :nodoc: #
      result = WIN32OLE.connect('Excel.Application') rescue nil
      if result
        begin
          result.Visible    # send any method, just to see if it responds
        rescue 
          trace "dead excel " + ("Window-handle = #{result.HWnd}" rescue "without window handle")
          return nil
        end
      end
      result
    end

  public

    # closes the Excel
    # @param [Hash] options the options
    # @option options [Symbol] :if_unsaved :raise, :save, :forget, or :keep_open
    # @option options [Boolean] :hard      
    #  :if_unsaved    if unsaved workbooks are open in an Excel instance
    #                      :raise (default) -> raises an exception       
    #                      :save            -> saves the workbooks before closing
    #                      :forget          -> closes the Excel instance without saving the workbooks 
    #                      :keep_open       -> keeps the Excel instance open 
    #  :hard          kill the Excel instance hard (default: false) 
    def close(options = {})
      options = {
        :if_unsaved => :raise,
        :hard => false
      }.merge(options)      
      close_excel(options) if managed_unsaved_workbooks(options)
    end

    # closes all Excel instances
    # @param [Hash] options the options
    # @option options [Symbol]  :if_unsaved :raise, :save, :forget, or :alert
    # @option options [Boolean] :hard
    # @option options [Boolean] :kill_if_timeout
    # options:
    #  :if_unsaved    if unsaved workbooks are open in an Excel instance
    #                      :raise (default) -> raises an exception       
    #                      :save            -> saves the workbooks before closing
    #                      :forget          -> closes the excel instance without saving the workbooks 
    #                      :alert           -> give control to Excel
    #  :hard          closes Excel instances soft (default: false), or, additionally kills the Excel processes hard (true)
    #  :kill_if_timeout:  kills Excel instances hard if the closing process exceeds a certain time limit (default: false)
    # @raise ExcelError if time limit has exceeded, some Excel instance cannot be closed, or
    #                   unsaved workbooks exist and option :if_unsaved is :raise
    def self.close_all(options={})
      options = {
        :if_unsaved => :raise,
        :hard => false,
        :kill_if_timeout => false
      }.merge(options)           
      timeout = false
      number = excels_number
      begin
        status = Timeout::timeout(15) {
          while (excels_number > 0) do
            ole_xl = current_excel    
            begin
              (Excel.new(ole_xl).close(options); Excel.new(ole_xl).close(options)) if ole_xl  # two times necessary ?!
            rescue RuntimeError => msg
              raise msg unless msg.message =~ /failed to get Dispatch Interface/
            end
          end
        }
      rescue Timeout::Error
        raise ExcelError, "close_all: timeout" unless options[:kill_if_timeout]
        timeout = true
      end
      kill_all if options[:hard] || (timeout && options[:kill_if_timeout])
      init
      number
    end

    def close_excel(options) # :nodoc:
      ole_xl = @ole_excel
      begin
        if options[:if_unsaved] == :alert
          with_displayalerts(true) {ole_xl.Workbooks.Close}
        else
          ole_xl.Workbooks.Close
        end
      rescue WIN32OLERuntimeError => msg
        raise ExcelUserCanceled, "close: canceled by user" if msg.message =~ /80020009/ && 
              options[:if_unsaved] == :alert && (not unsaved_workbooks.empty?)
      end     
      excel_hwnd = ole_xl.HWnd
      ole_xl.Quit
      weak_excel_ref = WeakRef.new(ole_xl)
      ole_xl = @ole_excel = nil
      GC.start
      sleep 0.2
      if weak_excel_ref.weakref_alive? then
        begin
          weak_excel_ref.ole_free
          #trace "successfully ole_freed #{weak_excel_ref}"
        rescue => msg
          trace "#{msg.message}"
          trace "could not do ole_free on #{weak_excel_ref}"
        end
      end
      @@hwnd2excel.delete(excel_hwnd)      
      if options[:hard] then
        process_id = Win32API.new("user32", "GetWindowThreadProcessId", ["I","P"], "I")
        pid_puffer = " " * 32
        process_id.call(excel_hwnd, pid_puffer)
        pid = pid_puffer.unpack("L")[0]
        Process.kill("KILL", pid) rescue nil   
      end
    end

  private

    def managed_unsaved_workbooks(options)   
      unsaved_workbooks = []      
      begin
        @ole_excel.Workbooks.each {|w| unsaved_workbooks << w unless (w.Saved || w.ReadOnly)}
      rescue RuntimeError => msg
        trace "RuntimeError: #{msg.message}" 
        raise ExcelErrorOpen, "Excel instance not alive or damaged" if msg.message =~ /failed to get Dispatch Interface/
      end
      unless unsaved_workbooks.empty? 
        case options[:if_unsaved]
        when :raise
          raise ExcelErrorClose, "Excel contains unsaved workbooks"
        when :save
          unsaved_workbooks.each do |workbook|
            workbook.Save
          end
          return true
        when :forget
          # nothing
        when :alert
          # nothing
        when :keep_open
          return false
        else
          raise ExcelErrorClose, ":if_unsaved: invalid option: #{options[:if_unsaved].inspect}"
        end
      end
      return true
    end

    # frees all OLE objects in the object space
    def self.free_all_ole_objects     # :nodoc: #
      anz_objekte = 0
      ObjectSpace.each_object(WIN32OLE) do |o|        
        anz_objekte += 1
        #trace "#{anz_objekte} name: #{(o.Name rescue (o.Count rescue "no_name"))} ole_object_name: #{(o.ole_object_name rescue nil)} type: #{o.ole_type rescue nil}"
        #trace [:Name, (o.Name rescue (o.Count rescue "no_name"))]
        #trace [:ole_object_name, (o.ole_object_name rescue nil)]
        #trace [:methods, (o.ole_methods rescue nil)] unless (o.Name rescue false)
        #trace o.ole_type rescue nil
        begin
          o.ole_free
          #trace "olefree OK"
        rescue
          #trace "olefree_error: #{$!}"
          #trace $!.backtrace.first(9).join "\n"
        end
      end
      trace "went through #{anz_objekte} OLE objects"
    end   


    def self.init
      @@hwnd2excel = {}
    end    

  public

    # kill all Excel instances
    # @return [Fixnum] number of killed Excel processes
    def self.kill_all
      procs = WIN32OLE.connect("winmgmts:\\\\.")
      processes = procs.InstancesOf("win32_process")
      number = processes.select{|p| (p.name == "EXCEL.EXE")}.size
      procs.InstancesOf("win32_process").each do |p|
        begin
          Process.kill('KILL', p.processid) if p.name == "EXCEL.EXE"        
        rescue 
           trace "kill error: #{$!}"
        end
      end
      init
      number
    end

    def self.excels_number
      WIN32OLE.connect("winmgmts:\\\\.").InstancesOf("win32_process").select{|p| (p.name == "EXCEL.EXE")}.size
    end

=begin
    # provide Excel objects 
    # (so far restricted to all Excel instances opened with RobustExcelOle,
    #  not for Excel instances opened by the user)
    def self.excel_processes
      pid2excel = {}
      @@hwnd2excel.each do |hwnd,wr_excel|
        excel = wr_excel.__getobj__
        process_id = Win32API.new("user32", "GetWindowThreadProcessId", ["I","P"], "I")
        pid_puffer = " " * 32
        process_id.call(hwnd, pid_puffer)
        pid = pid_puffer.unpack("L")[0]
        pid2excel[pid] = excel
      end
      procs = WIN32OLE.connect("winmgmts:\\\\.")
      processes = procs.InstancesOf("win32_process")     
      result = []
      processes.each do |p|
        if p.name == "EXCEL.EXE"
          if pid2excel.include?(p.processid)
            excel = pid2excel[p.processid]
            result << excel
          end
          # how to connect to an (interactively opened) Excel instance and get a WIN32OLE object?
          # after that, lift it to an Excel object
        end
      end
      result
    end
=end    

    def excel   # :nodoc: #
      self
    end

    def self.hwnd2excel(hwnd)   # :nodoc: #
      excel_weakref = @@hwnd2excel[hwnd]
      if excel_weakref
        if excel_weakref.weakref_alive?
          excel_weakref.__getobj__
        else
          trace "dead reference to an Excel"
          begin 
            @@hwnd2excel.delete(hwnd)
          rescue
            trace "Warning: deleting dead reference failed! (hwnd: #{hwnd.inspect})"
          end
        end
      end
    end

    def hwnd   # :nodoc: #
      self.Hwnd rescue nil
    end

    def self.print_hwnd2excel    # :nodoc: #
      @@hwnd2excel.each do |hwnd,wr_excel|
        excel_string = (wr_excel.weakref_alive? ? wr_excel.__getobj__.to_s : "weakref not alive") 
        printf("hwnd: %8i => excel: %s\n", hwnd, excel_string)
      end
      @@hwnd2excel.size
    end

    # returns true, if the Excel instances are alive and identical, false otherwise
    def == other_excel
      self.Hwnd == other_excel.Hwnd  if other_excel.is_a?(Excel) && self.alive? && other_excel.alive?
    end

    # returns true, if the Excel instances responds to VBA methods, false otherwise
    def alive?
      @ole_excel.Name
      true
    rescue
      #trace $!.message
      false
    end

    
    # returns all unsaved workbooks in Excel instances
    def self.unsaved_workbooks_all    # :nodoc: #
      result = []
      @@hwnd2excel.each do |hwnd,wr_excel| 
        excel = wr_excel.__getobj__
        result << excel.unsaved_workbooks
      end
      result
    end

    # returns unsaved workbooks
    def unsaved_workbooks
      result = []
      begin
        self.Workbooks.each {|w| result << w unless (w.Saved || w.ReadOnly)}
      rescue RuntimeError => msg
        trace "RuntimeError: #{msg.message}" 
        raise ExcelErrorOpen, "Excel instance not alive or damaged" if msg.message =~ /failed to get Dispatch Interface/
      end
      result      
    end

    def print_workbooks
      self.Workbooks.each {|w| puts "#{w.Name} #{w}"}
    end

    # generates, saves, and closes empty workbook
    def generate_workbook file_name                  
      self.Workbooks.Add                           
      empty_workbook = self.Workbooks.Item(self.Workbooks.Count)          
      filename = General::absolute_path(file_name).gsub("/","\\")
      unless File.exists?(filename)
        begin
          empty_workbook.SaveAs(filename) 
        rescue WIN32OLERuntimeError => msg
          if msg.message =~ /SaveAs/ and msg.message =~ /Workbook/ then
            raise ExcelErrorSave, "could not save workbook with filename #{file_name.inspect}"
          else
            # todo some time: find out when this occurs : 
            raise ExcelErrorSaveUnknown, "unknown WIN32OELERuntimeError with filename #{file_name.inspect}: \n#{msg.message}"
          end
        end      
      end
      empty_workbook                               
    end

    # sets DisplayAlerts in a block
    def with_displayalerts displayalerts_value
      old_displayalerts = self.displayalerts
      self.displayalerts = displayalerts_value
      begin
         yield self
      ensure
        self.displayalerts = old_displayalerts if alive?
      end
    end    

    # enables DisplayAlerts in the current Excel instance
    def displayalerts= displayalerts_value
      @displayalerts = displayalerts_value
      @ole_excel.DisplayAlerts = (@displayalerts == :if_visible) ? @ole_excel.Visible : displayalerts_value
    end

    # makes the current Excel instance visible or invisible
    def visible= visible_value
      @ole_excel.Visible = @visible = visible_value
      @ole_excel.DisplayAlerts = @visible if @displayalerts == :if_visible
    end   

    # make all workbooks visible or invisible
    def workbooks_visible= visible_value
      begin
        @ole_excel.Workbooks.each do |ole_wb| 
          workbook = Book.new(ole_wb)
          workbook.visible = visible_value
        end
      rescue RuntimeError => msg
        trace "RuntimeError: #{msg.message}" 
        raise ExcelErrorOpen, "Excel instance not alive or damaged" if msg.message =~ /failed to get Dispatch Interface/
      end
    end

    # sets calculation mode in a block
    def with_calculation(calculation_mode = :automatic)
      if @ole_excel.Workbooks.Count > 0
        old_calculation_mode = @ole_excel.Calculation
        old_calculation_before_save_mode = @ole_excel.CalculateBeforeSave
        @ole_excel.Calculation = calculation_mode == :automatic ? XlCalculationAutomatic : XlCalculationManual
        @ole_excel.CalculateBeforeSave = (calculation_mode == :automatic)
        begin
          yield self
        ensure
          @ole_excel.Calculation = old_calculation_mode if alive?
          @ole_excel.CalculateBeforeSave = old_calculation_before_save_mode if alive?
        end
      end
    end

    # sets calculation mode
    def set_calculation(calculation_mode = :automatic)
      if @ole_excel.Workbooks.Count > 0
        @ole_excel.Calculation = calculation_mode == :automatic ? XlCalculationAutomatic : XlCalculationManual
        @ole_excel.CalculateBeforeSave = (calculation_mode == :automatic)
      end
    end

    # returns the value of a range
    # @param [String] name the name of a range
    # @returns [Variant] the value of the range
    def [] name
      nameval(name)
    end

    # sets the value of a range
    # @param [String]  name  the name of the range
    # @param [Variant] value the contents of the range
    def []= (name, value)
      set_nameval(name,value)
    end

    # returns the contents of a range with given name
    # evaluates the formula if the contents is a formula
    # if no contents could be returned, then return default value, if provided, raise error otherwise
    # @param [String] name  the range name
    # @param [Hash]   opts  the options
    # @option opts [Variant] :default default value (default: nil)
    # @raise ExcelError if name is not defined or if value of the range cannot be evaluated
    def nameval(name, opts = {:default => nil})
      begin
        name_obj = self.Names.Item(name)
      rescue WIN32OLERuntimeError
        return opts[:default] if opts[:default]
        raise ExcelError, "cannot find name #{name.inspect}"
      end
      begin
        value = name_obj.RefersToRange.Value
      rescue  WIN32OLERuntimeError
        begin
          value = self.Evaluate(name_obj.Name)
        rescue WIN32OLERuntimeError
          return opts[:default] if opts[:default]
          raise ExcelError, "cannot evaluate name #{name.inspect}"
        end
      end
      if value == -2146826259
        return opts[:default] if opts[:default]
        raise ExcelError, "cannot evaluate name #{name.inspect}"
      end 
      return opts[:default] if (value.nil? && opts[:default])
      value      
    end
    
    # assigns a value to a range with given name
    # @param [String]  name   the range name
    # @param [Variant] value  the assigned value
    # @raise ExcelError if name is not in the sheet or the value cannot be assigned
    def set_nameval(name,value)
      begin
        name_obj = self.Names.Item(name)
      rescue WIN32OLERuntimeError
        raise ExcelError, "cannot find name #{name.inspect}"
      end
      begin
        name_obj.RefersToRange.Value = value
      rescue  WIN32OLERuntimeError
        raise ExcelError, "cannot assign value to range named #{name.inspect}"
      end
    end    

    # returns the contents of a range with a defined local name
    # evaluates the formula if the contents is a formula
    # if no contents could be returned, then return default value, if provided, raise error otherwise
    # @param  [String]      name      the range name
    # @param  [Hash]        opts      the options
    # @option opts [Symbol] :default  the default value that is provided if no contents could be returned
    # @raise  ExcelError if range name is not definied in the worksheet or if range value could not be evaluated
    # @return [Variant] the contents of a range with given name   
    def rangeval(name, opts = {:default => nil})
      begin
        range = self.Range(name)
      rescue WIN32OLERuntimeError
        return opts[:default] if opts[:default]
        raise ExcelError, "cannot find name #{name.inspect}"
      end
      begin
        value = range.Value
      rescue  WIN32OLERuntimeError
        return opts[:default] if opts[:default]
        raise ExcelError, "cannot determine value of range named #{name.inspect}"
      end
      return opts[:default] if (value.nil? && opts[:default])
      value
    end

    # assigns a value to a range given a defined loval name
    # @param [String]  name   the range name
    # @param [Variant] value  the assigned value
    # @raise ExcelError if name is not in the sheet or the value cannot be assigned
    def set_rangeval(name,value)
      begin
        range = self.Range(name)
      rescue WIN32OLERuntimeError
        raise ExcelError, "cannot find name #{name.inspect}"
      end
      begin
        range.Value = value
      rescue  WIN32OLERuntimeError
        raise ExcelError, "cannot assign value to range named #{name.inspect} in #{self.name}"
      end
    end

    def to_s              # :nodoc: #
      "#<Excel: " + "#{hwnd}" + ("#{"not alive" unless self.alive?}") + ">"
    end

    def inspect           # :nodoc: #
      self.to_s
    end

    def self.book_class   # :nodoc: #
      @book_class ||= begin
        module_name = self.parent_name
        "#{module_name}::Book".constantize
      rescue NameError => e
        book
      end
    end

    def book_class        # :nodoc: #
      self.class.book_class
    end

    include MethodHelpers

  private

    def method_missing(name, *args)    # :nodoc: #
      if name.to_s[0,1] =~ /[A-Z]/ 
        begin          
          raise ExcelError, "method missing: Excel not alive" unless alive?
          @ole_excel.send(name, *args)
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

  end  
end
