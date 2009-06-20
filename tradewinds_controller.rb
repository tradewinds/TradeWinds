#
#  tradewinds_controller.rb
#  TradeWinds
#

require 'osx/cocoa'
require 'find'

BOOK_SIG = "BOOKMOBI"
DEFAULT_BACKUP_DIR = '~/Library/Application Support/MobileSync/Backup'
DEFAULT_OUTPUT_DIR = '~/Documents'

class TradewindsController < OSX::NSObject
  include OSX
  
  ib_outlet :backup_dir, :output_dir, :iphone_id, :ebooks_view, :window
  ib_action :scan
  ib_action :select_backup_dir
  ib_action :select_output_dir
  ib_action :decrypt_ebooks
  
  def initialize()
    @ebooks = Array.new
    @resources_dir = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
    @kindle_pid_script = File.join(@resources_dir, 'kindlepid.py')
    @decrypt_script = File.join(@resources_dir, 'decrypt-mobi.py')
  end
  
  def awakeFromNib
    load_prefs
  end
  
  def applicationWillTerminate(aNotification)
    save_prefs
  end
    
  def load_prefs
    defaults = NSUserDefaults.standardUserDefaults;
    @backup_dir.setStringValue(defaults.objectForKey('backup_dir') || DEFAULT_BACKUP_DIR)
    @output_dir.setStringValue(defaults.objectForKey('output_dir') || DEFAULT_OUTPUT_DIR)
    @iphone_id.setStringValue(defaults.objectForKey('iphone_id') || '')
  end

  def save_prefs
    defaults = NSUserDefaults.standardUserDefaults;
    defaults.setObject_forKey(@backup_dir.stringValue, 'backup_dir')
    defaults.setObject_forKey(@output_dir.stringValue, 'output_dir')
    defaults.setObject_forKey(@iphone_id.stringValue, 'iphone_id')
    defaults.synchronize
  end

  def scan(sender)
    @ebooks.clear()
    dir = File.expand_path(@backup_dir.stringValue)
    Dir["#{dir}/**/*"].each do |path|
      if File.file?(path)
        data = File.read(path, 1024)
        if data =~ /#{BOOK_SIG}/
        
          # try figure out a readable book name, default to filename
          if /^([[:graph:]]+)/ =~ data
            name = $1
          end
          name = File.basename(path, File.extname(path)) if name.nil? || name.strip.size == 0
          
          book = {'name' => name, 'path' => path}
          @ebooks << book
        end
      end
    end
    @ebooks_view.reloadData
  end
  
  def select_backup_dir(sender)
    select_dir(@backup_dir)
  end
  
  def select_output_dir(sender)
    select_dir(@output_dir)
  end
  
  def select_dir(textView)
    oPanel = NSOpenPanel.openPanel
    oPanel.setAllowsMultipleSelection(false)
    oPanel.setCanChooseDirectories(true)
    oPanel.setCanChooseFiles(false)

    buttonClicked = oPanel.runModalForDirectory_file_types(textView.stringValue, nil, nil)
    if buttonClicked == NSOKButton
      dir = oPanel.filenames.objectAtIndex(0)
      textView.setStringValue(dir)
    end
  end
  
  def decrypt_ebooks(sender)
    idxs = @ebooks_view.selectedRowIndexes().to_a
    cmd = "python '#{@kindle_pid_script}' #{@iphone_id.stringValue} 2>&1"
    p cmd
    result = `#{cmd}`
    @pid = result.split.last
    if $?.exitstatus > 0 || @pid.strip.size == 0
      alert("Pid extraction failed", "Unable to get PID from iphone id: #{result}", true)
      return
    end
    idxs.each do |i|
      book = @ebooks[i]
      decrypt_ebook(book['name'], book['path'])
    end
  end
  
  def decrypt_ebook(name, path)
    out = File.join(File.expand_path(@output_dir.stringValue), "#{name}.mobi")
    cmd = "python '#{@decrypt_script}' '#{path}' '#{out}' #{@pid} 2>&1"
    p cmd
    result = `#{cmd}`
    if $?.exitstatus > 0
       alert("Decrypt failed", "Unable to get decrypt ebook #{name}: #{result}", true)
    end
  end
  
  def numberOfRowsInTableView(aTableView)
    return @ebooks.size
  end
  
  def tableView_objectValueForTableColumn_row(afileTable, aTableColumn, rowIndex)
    col = aTableColumn.identifier.to_s
    return @ebooks[rowIndex][col]
  end
    
  def alert(title, msg, is_error=false)
    alert = NSAlert.alloc.init
		alert.setMessageText(title)
		alert.setInformativeText(msg)
		alert.setAlertStyle(is_error ? NSCriticalAlertStyle : NSInformationalAlertStyle)
		alert.addButtonWithTitle("Ok")
    alert.beginSheetModalForWindow_modalDelegate_didEndSelector_contextInfo(@window, self, nil, nil)
  end

end
