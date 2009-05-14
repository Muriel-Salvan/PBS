#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Define general constants
  ID_TAG = 0
  ID_SHORTCUT = 1

  # This module define methods that are useful to several functions in PBS, but are not GUI related.
  # They could be used in a command-line mode.
  # No reference to Wx should present in here
  module Tools

    # Object that is used with the clipboard
    class DataObjectTag < Wx::DataObjectSimple

      # Get the data format
      #
      # Return:
      # * <em>Wx::DataFormat</em>: The data format
      def self.getDataFormat
        if (!defined?(@@PBS_CLIPBOARD_DATA_FORMAT))
          # Custom format, that ensures only PBS will use this clipboard data
          @@PBS_CLIPBOARD_DATA_FORMAT = Wx::DataFormat.new('PBSClipboardDataFormat')
        end
        return @@PBS_CLIPBOARD_DATA_FORMAT
      end

      # Constructor
      def initialize
        super(DataObjectTag.getDataFormat)
      end

      # The data to encapsulate
      #   String
      attr_accessor :Data

      # Method used by the clipboard itself to fill data
      #
      # Parsameters:
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # * *iData* (_String_): The data
      def set_data(iFormat, iData)
        @Data = iData
      end

      # Method used by Wxruby to retrieve the data
      #
      # Parameters:
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # Return:
      # * _String_: The data
      def get_data_here(iFormat)
        return @Data
      end

    end

    # Create an image list, considering the minimal size of every image given as input.
    #
    # Parameters:
    # * *iFileNames* (<em>list<String></em>): File names list, relative to PBS directory
    # Return:
    # * <em>Wx::ImageList</em>: The image list
    def createImageList(iFileNames)
      lBitmapList = []
      lMinWidth = nil
      lMinHeight = nil
      # Read every file given as input, and get minimal width/height
      iFileNames.each do |iFileName|
        lBitmap = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/#{iFileName}")
        if ((lMinWidth == nil) or
            (lBitmap.width < lMinWidth))
          lMinWidth = lBitmap.width
        end
        if ((lMinHeight == nil) or
            (lBitmap.height < lMinHeight))
          lMinHeight = lBitmap.height
        end
        lBitmapList << lBitmap
      end
      if (lMinWidth == nil)
        # No image, empty list will be returned
        lMinWidth = 0
        lMinHeight = 0
      end
      # Create the image list and populate it with the previously read bitmaps
      rImageList = Wx::ImageList.new(lMinWidth, lMinHeight)
      lBitmapList.each do |iBitmap|
        rImageList << iBitmap
      end
      return rImageList
    end

    # Save data in a file
    #
    # Parameters:
    # * *iRootTag* (_Tag_): The root tag, used to store all tags
    # * *iShortcuts* (<em>list<Shortcut></em>): The list of shortcuts to store
    # * *iFileName* (_String_): The file name to save into
    def saveData(iRootTag, iShortcuts, iFileName)
      # First serialize our data to store
      lSerializedTags = []
      iRootTag.Children.each do |iTag|
        lSerializedTags << iTag.getSerializedData
      end
      lSerializedShortcuts = []
      iShortcuts.each do |iSC|
        lSerializedShortcuts << iSC.getSerializedData
      end
      # Then, marshall this data
      lData = Marshal.dump([ lSerializedTags, lSerializedShortcuts ])
      # The write everything in the file
      File.open(iFileName, 'w') do |iFile|
        iFile.write(lData)
      end
    end

    # Open data from a file
    #
    # Parameters:
    # * *iTypes* (<em>map<String,Object></em>): The known types
    # * *iFileName* (_String_): The file name to load from
    # Return:
    # * _Tag_: The root tag
    # * <em>list<Shortcut></em>: The list of shortcuts
    def openData(iTypes, iFileName)
      rRootTag = Tag.new('Root', nil)
      rShortcuts = []

      # First read the file
      lData = nil
      File.open(iFileName, 'r') do |iFile|
        lData = iFile.read
      end
      # Unmarshal it
      lSerializedTags, lSerializedShortcuts = Marshal.load(lData)
      # Deserialize Tags
      lSerializedTags.each do |iSerializedTagData|
        Tag.createTagFromSerializedData(rRootTag, iSerializedTagData)
      end
      # Deserialize Shortcuts
      lSerializedShortcuts.each do |iSerializedShortcutData|
        lNewShortcut = Shortcut.createShortcutFromSerializedData(rRootTag, iTypes, iSerializedShortcutData, false)
        if (lNewShortcut != nil)
          rShortcuts << lNewShortcut
        end
      end

      return rRootTag, rShortcuts
    end

    # Translate old Tags (belonging to an obsolete root) into new ones.
    #
    # Parameters:
    # * *iOldTags* (<em>map<Tag,nil></em>): The old Tags
    # * *ioNewTags* (<em>map<Tag,nil></em>): The new Tags
    # * *iRootTag* (_Tag_): The root Tag to consider for new ones
    def translateTags(iOldTags, ioNewTags, iRootTag)
      iOldTags.each do |iTag, iNil|
        lTagID = iTag.getUniqueID
        lNewCorrespondingTag = iRootTag.searchTag(lTagID)
        if (lNewCorrespondingTag == nil)
          puts "!!! Normally Tag #{lTagID.join('/')} should have been merged, but it appears we can't retrieve it after the merge. Ignoring this Tag."
        else
          ioNewTags[lNewCorrespondingTag] = nil
        end
      end
    end

    # Clone a complete Tags tree, and a list of Shortcuts.
    # It also takes care of the Tags references from the Shortcuts to point also to the cloned Tags.
    #
    # Parameters:
    # * *iRootTag* (_Tag_): The root Tag
    # * *iShortcutsList* (<em>list<Shortcut></em>): The list of Shortcuts
    # Return:
    # * _Tag_: The cloned root Tag
    # * <em>list<Shortcut></em>: The cloned list of Shortcuts
    def cloneTagsShortcuts(iRootTag, iShortcutsList)
      rClonedRootTag = iRootTag.clone(nil)
      rClonedShortcutsList = []

      iShortcutsList.each do |iSC|
        lNewSC = iSC.clone
        lNewTags = {}
        translateTags(lNewSC.Tags, lNewTags, rClonedRootTag)
        lNewSC.replaceTags(lNewTags)
        rClonedShortcutsList << lNewSC
      end

      return rClonedRootTag, rClonedShortcutsList
    end

    # Get the string representation of an accelerator
    #
    # Parameters:
    # * *iAccelerator* (<em>[Integer,Integer]</em>): The accelerator info
    # Return:
    # * _String_: The visual representation of this accelerator
    def getStringForAccelerator(iAccelerator)
      rResult = ''

      lModifier, lKey = iAccelerator

      # Display modifier
      if (lModifier & Wx::MOD_META != 0)
        rResult << 'Meta+'
      end
      if (lModifier & Wx::MOD_CONTROL != 0)
        rResult << 'Ctrl+'
      end
      if (lModifier & Wx::MOD_ALT != 0)
        rResult << 'Alt+'
      end
      if (lModifier & Wx::MOD_SHIFT != 0)
        rResult << 'Maj+'
      end

      # Display key
      case lKey
      when Wx::K_BACK
        rResult << 'Backspace'
      when Wx::K_TAB
        rResult << 'Tab'
      when Wx::K_RETURN
        rResult << 'Enter'
      when Wx::K_ESCAPE
        rResult << 'Escape'
      when Wx::K_SPACE
        rResult << 'Space'
      when Wx::K_DELETE
        rResult << 'Del'
      when Wx::K_START
        rResult << 'Start'
      when Wx::K_LBUTTON
        rResult << 'Mouse Left'
      when Wx::K_RBUTTON
        rResult << 'Mouse Right'
      when Wx::K_CANCEL
        rResult << 'Cancel'
      when Wx::K_MBUTTON
        rResult << 'Mouse Middle'
      when Wx::K_CLEAR
        rResult << 'Clear'
      when Wx::K_SHIFT
        rResult << 'Shift'
      when Wx::K_ALT
        rResult << 'Alt'
      when Wx::K_CONTROL
        rResult << 'Control'
      when Wx::K_MENU
        rResult << 'Menu'
      when Wx::K_PAUSE
        rResult << 'Pause'
      when Wx::K_CAPITAL
        rResult << 'Capital'
      when Wx::K_END
        rResult << 'End'
      when Wx::K_HOME
        rResult << 'Home'
      when Wx::K_LEFT
        rResult << 'Left'
      when Wx::K_UP
        rResult << 'Up'
      when Wx::K_RIGHT
        rResult << 'Right'
      when Wx::K_DOWN
        rResult << 'Down'
      when Wx::K_SELECT
        rResult << 'Select'
      when Wx::K_PRINT
        rResult << 'Print'
      when Wx::K_EXECUTE
        rResult << 'Execute'
      when Wx::K_SNAPSHOT
        rResult << 'Snapshot'
      when Wx::K_INSERT
        rResult << 'Ins'
      when Wx::K_HELP
        rResult << 'Help'
      when Wx::K_NUMPAD0
        rResult << 'Num 0'
      when Wx::K_NUMPAD1
        rResult << 'Num 1'
      when Wx::K_NUMPAD2
        rResult << 'Num 2'
      when Wx::K_NUMPAD3
        rResult << 'Num 3'
      when Wx::K_NUMPAD4
        rResult << 'Num 4'
      when Wx::K_NUMPAD5
        rResult << 'Num 5'
      when Wx::K_NUMPAD6
        rResult << 'Num 6'
      when Wx::K_NUMPAD7
        rResult << 'Num 7'
      when Wx::K_NUMPAD8
        rResult << 'Num 8'
      when Wx::K_NUMPAD9
        rResult << 'Num 9'
      when Wx::K_MULTIPLY
        rResult << '*'
      when Wx::K_ADD
        rResult << '+'
      when Wx::K_SEPARATOR
        rResult << 'Separator'
      when Wx::K_SUBTRACT
        rResult << '-'
      when Wx::K_DECIMAL
        rResult << '.'
      when Wx::K_DIVIDE
        rResult << '/'
      when Wx::K_F1
        rResult << 'F1'
      when Wx::K_F2
        rResult << 'F2'
      when Wx::K_F3
        rResult << 'F3'
      when Wx::K_F4
        rResult << 'F4'
      when Wx::K_F5
        rResult << 'F5'
      when Wx::K_F6
        rResult << 'F6'
      when Wx::K_F7
        rResult << 'F7'
      when Wx::K_F8
        rResult << 'F8'
      when Wx::K_F9
        rResult << 'F9'
      when Wx::K_F10
        rResult << 'F10'
      when Wx::K_F11
        rResult << 'F11'
      when Wx::K_F12
        rResult << 'F12'
      when Wx::K_F13
        rResult << 'F13'
      when Wx::K_F14
        rResult << 'F14'
      when Wx::K_F15
        rResult << 'F15'
      when Wx::K_F16
        rResult << 'F16'
      when Wx::K_F17
        rResult << 'F17'
      when Wx::K_F18
        rResult << 'F18'
      when Wx::K_F19
        rResult << 'F19'
      when Wx::K_F20
        rResult << 'F20'
      when Wx::K_F21
        rResult << 'F21'
      when Wx::K_F22
        rResult << 'F22'
      when Wx::K_F23
        rResult << 'F23'
      when Wx::K_F24
        rResult << 'F24'
      when Wx::K_NUMLOCK
        rResult << 'Numlock'
      when Wx::K_SCROLL
        rResult << 'Scroll'
      when Wx::K_PAGEUP
        rResult << 'PageUp'
      when Wx::K_PAGEDOWN
        rResult << 'PageDown'
      when Wx::K_NUMPAD_SPACE
        rResult << 'Num Space'
      when Wx::K_NUMPAD_TAB
        rResult << 'Num Tab'
      when Wx::K_NUMPAD_ENTER
        rResult << 'Num Enter'
      when Wx::K_NUMPAD_F1
        rResult << 'Num F1'
      when Wx::K_NUMPAD_F2
        rResult << 'Num F2'
      when Wx::K_NUMPAD_F3
        rResult << 'Num F3'
      when Wx::K_NUMPAD_F4
        rResult << 'Num F4'
      when Wx::K_NUMPAD_HOME
        rResult << 'Num Home'
      when Wx::K_NUMPAD_LEFT
        rResult << 'Num Left'
      when Wx::K_NUMPAD_UP
        rResult << 'Num Up'
      when Wx::K_NUMPAD_RIGHT
        rResult << 'Num Right'
      when Wx::K_NUMPAD_DOWN
        rResult << 'Num Down'
      when Wx::K_NUMPAD_PAGEUP
        rResult << 'Num PageUp'
      when Wx::K_NUMPAD_PAGEDOWN
        rResult << 'Num PageDown'
      when Wx::K_NUMPAD_END
        rResult << 'Num End'
      when Wx::K_NUMPAD_BEGIN
        rResult << 'Num Begin'
      when Wx::K_NUMPAD_INSERT
        rResult << 'Num Ins'
      when Wx::K_NUMPAD_DELETE
        rResult << 'Num Del'
      when Wx::K_NUMPAD_EQUAL
        rResult << 'Num ='
      when Wx::K_NUMPAD_MULTIPLY
        rResult << 'Num *'
      when Wx::K_NUMPAD_ADD
        rResult << 'Num +'
      when Wx::K_NUMPAD_SEPARATOR
        rResult << 'Num Separator'
      when Wx::K_NUMPAD_SUBTRACT
        rResult << 'Num -'
      when Wx::K_NUMPAD_DECIMAL
        rResult << 'Num .'
      when Wx::K_NUMPAD_DIVIDE
        rResult << 'Num /'
      when Wx::K_WINDOWS_LEFT
        rResult << 'Win Left'
      when Wx::K_WINDOWS_RIGHT
        rResult << 'Win Right'
      when Wx::K_WINDOWS_MENU
        rResult << 'Win Menu'
      when Wx::K_COMMAND
        rResult << 'Command'
      when Wx::K_SPECIAL1
        rResult << 'Special 1'
      when Wx::K_SPECIAL2
        rResult << 'Special 2'
      when Wx::K_SPECIAL3
        rResult << 'Special 3'
      when Wx::K_SPECIAL4
        rResult << 'Special 4'
      when Wx::K_SPECIAL5
        rResult << 'Special 5'
      when Wx::K_SPECIAL6
        rResult << 'Special 6'
      when Wx::K_SPECIAL7
        rResult << 'Special 7'
      when Wx::K_SPECIAL8
        rResult << 'Special 8'
      when Wx::K_SPECIAL9
        rResult << 'Special 9'
      when Wx::K_SPECIAL10
        rResult << 'Special 10'
      when Wx::K_SPECIAL11
        rResult << 'Special 11'
      when Wx::K_SPECIAL12
        rResult << 'Special 12'
      when Wx::K_SPECIAL13
        rResult << 'Special 13'
      when Wx::K_SPECIAL14
        rResult << 'Special 14'
      when Wx::K_SPECIAL15
        rResult << 'Special 15'
      when Wx::K_SPECIAL16
        rResult << 'Special 16'
      when Wx::K_SPECIAL17
        rResult << 'Special 17'
      when Wx::K_SPECIAL18
        rResult << 'Special 18'
      when Wx::K_SPECIAL19
        rResult << 'Special 19'
      when Wx::K_SPECIAL20
        rResult << 'Special 20'
      else
        rResult << lKey.chr.upcase
      end

      return rResult
    end

  end

end
