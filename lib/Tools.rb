#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Define general constants
  ID_TAG = 0
  ID_SHORTCUT = 1

  # This class defines common methods for every type.
  # Every Shortcut type should inherit from it.
  class ShortcutType

    # Get the associated icon
    #
    # Return:
    # * <em>Wx::Bitmap</em>: The icon
    def getIcon
      if (!defined?(@Icon))
        # Create it: it is the first time we ask for it
        @Icon = Wx::Bitmap.new("#{$PBSRootDir}/#{getIconFileName}")
      end

      return @Icon
    end

  end

  # This module define methods that are useful to several functions in PBS, but are not GUI related.
  # They could be used in a command-line mode.
  # No reference to Wx should present in here
  module Tools

    # Object that is used with the clipboard
    class DataObjectSelection < Wx::DataObject

      # constructor
      def initialize
        super
        @Data = nil
        @DataAsText = nil
      end

      # Set the data to send to the clipboard
      #
      # Parameters:
      # * *iCopyType* (_Integer_): Type of the copy (Wx::ID_COPY/Wx::ID_CUT)
      # * *iCopyID* (_Integer_): ID of the copy
      # * *iSerializedTags* (<em>list<Object></em>): The list of serialized Tags, with their sub-Tags and Shortcuts (can be nil for acks)
      # * *iSerializedShortcuts* (<em>list<[Object,String]></em>): The list of serialized Shortcuts, with their parent Tag's ID (can be nil for acks)
      def setData(iCopyType, iCopyID, iSerializedTags, iSerializedShortcuts)
        @Data = Marshal.dump( [ iCopyType, iCopyID, iSerializedTags, iSerializedShortcuts ] )
        if (iSerializedTags == nil)
          @DataAsText = nil
        else
          @DataAsText = MultipleSelection::getSingleContent(iSerializedTags, iSerializedShortcuts)
        end
      end

      # Get the data from the clipboard
      #
      # Return:
      # * _Integer_: Type of the copy (Wx::ID_COPY/Wx::ID_CUT)
      # * _Integer_: ID of the copy
      # * <em>list<Object></em>: The list of serialized Tags, with their sub-Tags and Shortcuts (can be nil for acks)
      # * <em>list<[Object,String]></em>: The list of serialized Shortcuts, with their parent Tag's ID (can be nil for acks)
      def getData
        return Marshal.load(@Data)
      end

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

      # Get the list of all supported formats.
      #
      # Parameters:
      # * *iDirection* (_Object_): ? Not documented
      # Return:
      # * <em>list<Wx::DataFormat></em>: List of supported data formats
      def get_all_formats(iDirection)
        if (@DataAsText != nil)
          return [ DataObjectSelection.getDataFormat, Wx::DF_TEXT ]
        else
          return [ DataObjectSelection.getDataFormat ]
        end
      end

      # Method used by the clipboard itself to fill data
      #
      # Parameters:
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # * *iData* (_String_): The data
      def set_data(iFormat, iData)
        case iFormat
        when Wx::DF_TEXT
          @DataAsText = iData
        when DataObjectSelection.getDataFormat
          @Data = iData
        else
          puts "!!! Set unknown format: #{iFormat}"
        end
      end

      # Method used by Wxruby to retrieve the data
      #
      # Parameters:
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # Return:
      # * _String_: The data
      def get_data_here(iFormat)
        rData = nil

        case iFormat
        when Wx::DF_TEXT
          rData = @DataAsText
        when DataObjectSelection.getDataFormat
          rData = @Data
        else
          puts "!!! Asked unknown format: #{iFormat}"
        end

        return rData
      end

      # Redefine this method to be used with Wx::DataObjectComposite that requires it
      #
      # Parameters:
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # Return:
      # * _Integer_: The data size
      def get_data_size(iFormat)
        rDataSize = 0

        case iFormat
        when Wx::DF_TEXT
          # Add 1, otherwise it replaces last character with \0x00
          rDataSize = @DataAsText.length + 1
        when DataObjectSelection.getDataFormat
          rDataSize = @Data.length
        else
          puts "!!! Asked unknown format for size: #{iFormat}"
        end

        return rDataSize
      end

    end

    # Class that is used for drag'n'drop
    class SelectionDropSource < Wx::DropSource

      # Constructor
      #
      # Parameters:
      # * *iDragImage* (<em>Wx::DragImage</em>): The drag image to display
      # * *iWindow* (<em>Wx::Window</em>): The window initiating the Drag'n'Drop
      # * *iSelection* (_MultipleSelection_): The selection being dragged
      # * *iController* (_Controller_): The data model controller
      def initialize(iDragImage, iWindow, iSelection, iController)
        super(iWindow)

        @DragImage = iDragImage
        @Selection = iSelection
        @Controller = iController
        @OldEffect = nil

        # Create the serialized data
        lSerializedTags, lSerializedShortcuts = @Selection.getSerializedSelection
        lCopyID = @Controller.getNewCopyID
        lData = Tools::DataObjectSelection.new
        lData.setData(Wx::ID_CUT, lCopyID, lSerializedTags, lSerializedShortcuts)

        # Set the DropSource internal data
        self.data = lData
      end

      # Change appearance.
      #
      # Parameters:
      # * *iEffect* (_Integer_): The effect to implement. One of DragCopy, DragMove, DragLink and DragNone.
      # Return:
      # * _Boolean_: false if you want default feedback, or true if you implement your own feedback. The return values is ignored under GTK.
      def give_feedback(iEffect)
        # Drag the image
        @DragImage.move(Wx::get_mouse_position)
        # Change icons of items to be moved if the sugggested result (Move/Copy) has changed
        if (iEffect != @OldEffect)
          case iEffect
          when Wx::DRAG_MOVE
            @Controller.notifyObjectsDragMove(@Selection)
          when Wx::DRAG_COPY
            @Controller.notifyObjectsDragCopy(@Selection)
          else
            @Controller.notifyObjectsDragNone(@Selection)
          end
          @OldEffect = iEffect
        end
        # Default feedback is ok
        return false
      end

    end

    # Class that stores a selection of several Tags and Shortcuts alltogether
    class MultipleSelection

      # The list of Shortcuts IDs directly selected, with their corresponding parent Tag ID
      #   list< [ Integer, list< String > ] >
      attr_reader :SelectedPrimaryShortcuts

      # The list of Tags IDs directly selected
      #   list< list< String > >
      attr_reader :SelectedPrimaryTags

      # The list of Shortcuts IDs that are part of the selection because they belong to a selected Tag
      #   list< [ Integer, list< String > ] >
      attr_reader :SelectedSecondaryShortcuts

      # The list of Tags IDs that are part of the selection because they are a sub-Tag of a selected Tag
      #   list< list< String > >
      attr_reader :SelectedSecondaryTags

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      def initialize(iController)
        @Controller = iController
        @SerializedTags = nil
        @SerializedShortcuts = nil
        @SelectedPrimaryShortcuts = []
        @SelectedPrimaryTags = []
        @SelectedSecondaryShortcuts = []
        @SelectedSecondaryTags = []
      end

      # Add a Tag to the selection
      #
      # Parameters:
      # * *iTag* (_Tag_): The Tag to add (nil in case of the Root Tag)
      def selectTag(iTag)
        if (iTag == @Controller.RootTag)
          # In this case, it is different: we select every first level Tag, and Shortcuts having no Tags as primary selection.
          # This is equivalent to selecting everything.
          # Select Tags
          @Controller.RootTag.Children.each do |iChildTag|
            selectTag(iChildTag)
          end
          # Select Shortcuts
          @Controller.ShortcutsList.each do |iSC|
            if (iSC.Tags.empty?)
              selectShortcut(iSC, nil)
            end
          end
        else
          iTag.getSecondaryObjects(@Controller.ShortcutsList, @SelectedSecondaryShortcuts, @SelectedSecondaryTags)
          @SelectedPrimaryTags << iTag.getUniqueID
        end
      end

      # Add a Shortcut to the selection
      #
      # Parameters:
      # * *iShortcut* (_Shortcut_): The Shortcut
      # * *iParentTag* (_Tag_): The Tag from which the Shortcut was selected (nil for Root)
      def selectShortcut(iShortcut, iParentTag)
        if (iParentTag == nil)
          @SelectedPrimaryShortcuts << [ iShortcut.getUniqueID, @Controller.RootTag.getUniqueID ]
        else
          @SelectedPrimaryShortcuts << [ iShortcut.getUniqueID, iParentTag.getUniqueID ]
        end
      end

      # Is the given Tag selected as a primary selection ?
      #
      # Parameters:
      # * *iTag* (_Tag_): The Tag to check
      # Return:
      # * _Boolean_: Is the given Tag selected as a primary selection ?
      def isTagPrimary?(iTag)
        return @SelectedPrimaryTags.include?(iTag.getUniqueID)
      end

      # Is the given Tag selected as a secondary selection ?
      #
      # Parameters:
      # * *iTag* (_Tag_): The Tag to check
      # Return:
      # * _Boolean_: Is the given Tag selected as a secondary selection ?
      def isTagSecondary?(iTag)
        return @SelectedSecondaryTags.include?(iTag.getUniqueID)
      end

      # Is the given Shortcut selected as a primary selection ?
      #
      # Parameters:
      # * *iSC* (_Shortcut_): The Shortcut to check
      # * *iParentTag* (_Tag_): The corresponding parent Tag (can be nil for root)
      # Return:
      # * _Boolean_: Is the given Shortcut selected as a primary selection ?
      def isShortcutPrimary?(iSC, iParentTag)
        if (iParentTag == nil)
          return @SelectedPrimaryShortcuts.include?( [ iSC.getUniqueID, @Controller.RootTag.getUniqueID ] )
        else
          return @SelectedPrimaryShortcuts.include?( [ iSC.getUniqueID, iParentTag.getUniqueID ] )
        end
      end

      # Is the given Shortcut selected as a secondary selection ?
      #
      # Parameters:
      # * *iSC* (_Shortcut_): The Shortcut to check
      # * *iParentTag* (_Tag_): The corresponding parent Tag (can be nil for root)
      # Return:
      # * _Boolean_: Is the given Shortcut selected as a secondary selection ?
      def isShortcutSecondary?(iSC, iParentTag)
        if (iParentTag == nil)
          return @SelectedSecondaryShortcuts.include?( [ iSC.getUniqueID, @Controller.RootTag.getUniqueID ] )
        else
          return @SelectedSecondaryShortcuts.include?( [ iSC.getUniqueID, iParentTag.getUniqueID ] )
        end
      end

      # Is the selection empty ?
      #
      # Return:
      # * _Boolean_: Is the selection empty ?
      def empty?
        return ((@SelectedPrimaryShortcuts.empty?) and
                (@SelectedPrimaryTags.empty?))
      end

      # Is the selection about a single Tag ?
      #
      # Return:
      # * _Boolean_: Is the selection about a single Tag ?
      def singleTag?
        return ((@SelectedPrimaryShortcuts.empty?) and
                (@SelectedPrimaryTags.size == 1))
      end

      # Is the selection about a single Shortcut ?
      #
      # Return:
      # * _Boolean_: Is the selection about a single Shortcut ?
      def singleShortcut?
        return ((@SelectedPrimaryShortcuts.size == 1) and
                (@SelectedPrimaryTags.empty?))
      end

      # Return a simple string summary of what is selected
      #
      # Return:
      # * _String_: The simple description of the selection
      def getDescription
        rDescription = nil

        if (@SelectedPrimaryShortcuts.empty?)
          if (@SelectedPrimaryTags.empty?)
            rDescription = 'Empty'
          elsif (@SelectedPrimaryTags.size == 1)
            lTag = @Controller.findTag(@SelectedPrimaryTags[0])
            if (lTag == nil)
              puts "!!! Tag #{@SelectedPrimaryTags[0].join('/')} was selected, but does not exist in the data. Bug ?"
              rDescription = 'Error'
            else
              rDescription = "Tag #{lTag.Name}"
            end
          else
            rDescription = 'Multiple Tags'
          end
        elsif (@SelectedPrimaryTags.empty?)
          if (@SelectedPrimaryShortcuts.size == 1)
            lSC = @Controller.findShortcut(@SelectedPrimaryShortcuts[0][0])
            if (lSC == nil)
              puts "!!! Shortcut #{@SelectedPrimaryShortcuts[0][0]} was selected, but does not exist in the data. Bug ?"
              rDescription = 'Error'
            else
              rDescription = "Shortcut #{lSC.Metadata['title']}"
            end
          else
            rDescription = 'Multiple Shortcuts'
          end
        else
          rDescription = 'Multiple'
        end

        return rDescription
      end

      # Get a description from 2 lists of serialized Shortcuts and Tags returned by this class
      #
      # Parameters:
      # * *iSerializedTags* (<em>list<Object></em>): The list of serialized Tags, with their sub-Tags and Shortcuts
      # * *iSerializedShortcuts* (<em>list<Object]></em>): The list of serialized Shortcuts
      # Return:
      # * _String_: The simple description
      def self.getDescription(iSerializedTags, iSerializedShortcuts)
        rDescription = nil

        if (iSerializedShortcuts.empty?)
          if (iSerializedTags.empty?)
            rDescription = 'Empty'
          elsif (iSerializedTags.size == 1)
            rDescription = "Tag #{iSerializedTags[0].getName}"
          else
            rDescription = 'Multiple Tags'
          end
        elsif (iSerializedTags.empty?)
          if (iSerializedShortcuts.size == 1)
            rDescription = "Shortcut #{iSerializedShortcuts[0].getName}"
          else
            rDescription = 'Multiple Shortcuts'
          end
        else
          rDescription = 'Multiple'
        end

        return rDescription
      end

      # Get the content of a single selected and serialized Tag or Shortcut, or nil otherwise.
      # In fact this function is useful to give an alternate text representation of the data to be put in the clipboard.
      #
      # Parameters:
      # * *iSerializedTags* (<em>list<Object></em>): The list of serialized Tags, with their sub-Tags and Shortcuts
      # * *iSerializedShortcuts* (<em>list<Object></em>): The list of serialized Shortcuts
      # Return:
      # * _String_: The single content
      def self.getSingleContent(iSerializedTags, iSerializedShortcuts)
        rContent = nil

        if (iSerializedShortcuts.empty?)
          if (iSerializedTags.size == 1)
            rContent = iSerializedTags[0].getSingleClipContent
          end
        elsif (iSerializedTags.empty?)
          if (iSerializedShortcuts.size == 1)
            rContent = iSerializedShortcuts[0].getSingleClipContent
          end
        end

        return rContent
      end

      # Get the complete selected data in a serialized way (that is without any references to objects, ready to be marshalled)
      #
      # Return:
      # * <em>list< Object ></em>: The list of serialized Tags, with their sub-Tags and Shortcuts
      # * <em>list< Object ></em>: The list of serialized Shortcuts
      def getSerializedSelection
        if (@SerializedTags == nil)
          computeSerializedTags
        end
        if (@SerializedShortcuts == nil)
          computeSerializedShortcuts
        end
        return @SerializedTags, @SerializedShortcuts
      end

      # Create serialized Tags data
      def computeSerializedTags
        @SerializedTags = []
        @SelectedPrimaryTags.each do |iTagID|
          if (iTagID == [])
            # Root Tag
            @SerializedTags << @Controller.RootTag.getSerializedDataWithShortcuts(@Controller.ShortcutsList)
          else
            lTag = @Controller.findTag(iTagID)
            if (lTag == nil)
              puts "!!! Tag of ID #{iTagID.join('/')} should be part of the data, as it was marked as selected. Ignoring it. Bug ?"
            else
              @SerializedTags << lTag.getSerializedDataWithShortcuts(@Controller.ShortcutsList)
            end
          end
        end
      end

      # Create serialized Shortcuts data
      def computeSerializedShortcuts
        @SerializedShortcuts = []
        @SelectedPrimaryShortcuts.each do |iSCInfo|
          iSCID, iParentTagID = iSCInfo
          lSC = @Controller.findShortcut(iSCID)
          if (lSC == nil)
            puts "!!! Shortcut of ID #{iSCID} should be part of the data, as it was marked as selected. Ignoring it. Bug ?"
          else
            @SerializedShortcuts << lSC.getSerializedData(true)
          end
        end
      end

      # Get the bitmap representing this selection
      #
      # Parameters:
      # * *iFont* (<em>Wx::Font</em>): The font to be used to write
      # * *CodeBlock*: The code called once the bitmap has been created without alpha channel. This is used to put some modifications on it.
      # Return:
      # * <em>Wx::Bitmap</em>: The bitmap
      def getBitmap(iFont)
        # Paint the bitmap corresponding to the selection
        lWidth = 0
        lHeight = 0
        # Arbitrary max size
        lMaxWidth = 400
        lMaxHeight = 400
        lDragBitmap = Wx::Bitmap.new(lMaxWidth, lMaxHeight)
        lDragBitmap.draw do |ioDC|
          # White will be set as transparent afterwards
          ioDC.brush = Wx::WHITE_BRUSH
          ioDC.pen = Wx::WHITE_PEN
          ioDC.draw_rectangle(0, 0, lMaxWidth, lMaxHeight)
          lWidth, lHeight = draw(ioDC, iFont)
        end
        # Modify it before continuing
        lWidth, lHeight = yield(lDragBitmap, lWidth, lHeight)
        # Compute the alpha mask
        lSelectionImage = Wx::Image.from_bitmap(lDragBitmap)
        lSelectionImage.set_mask_colour(Wx::WHITE.red, Wx::WHITE.green, Wx::WHITE.blue)
        lSelectionImage.init_alpha
        lSelectionImage.convert_alpha_to_mask

        return Wx::Bitmap.from_image(lSelectionImage.resize([lWidth, lHeight], Wx::Point.new(0, 0)))
      end

      # Draw the selection in a device context
      #
      # Parameters:
      # * *ioDC* (<em>Wx::DC</em>): The device context to draw into
      # * *iFont* (<em>Wx::Font</em>): The font to be used to write
      # Return:
      # * _Integer_: The final width used to draw
      # * _Integer_: The final height used to draw
      def draw(ioDC, iFont)
        rFinalWidth = 0
        rFinalHeight = 0

        ioDC.font = iFont
        # Draw Shortcuts
        @SelectedPrimaryShortcuts.each do |iSCInfo|
          iSCID, iParentTagID = iSCInfo
          lSC = @Controller.findShortcut(iSCID)
          if (lSC == nil)
            puts "!!! Shortcut of ID #{iSCID} should be part of the data, as it was marked as selected. Ignoring it. Bug ?"
          else
            lTitle = lSC.Metadata['title']
            lWidth, lHeight, lDescent, lLeading = ioDC.get_text_extent(lTitle)
            if (lWidth > rFinalWidth)
              rFinalWidth = lWidth
            end
            ioDC.draw_text(lTitle, 0, rFinalHeight)
            rFinalHeight += lHeight + lLeading
          end
        end
        # Draw Tags
        @SelectedPrimaryTags.each do |iTagID|
          lTag = @Controller.findTag(iTagID)
          if (lTag == nil)
            puts "!!! Tag of ID #{iTagID.join('/')} should be part of the data, as it was marked as selected. Ignoring it. Bug ?"
          else
            lTitle = "#{lTag.Name} ..."
            lWidth, lHeight, lDescent, lLeading = ioDC.get_text_extent(lTitle)
            ioDC.draw_text(lTitle, 0, rFinalHeight)
            if (lWidth > rFinalWidth)
              rFinalWidth = lWidth
            end
            rFinalHeight += lHeight + lLeading
          end
        end

        return rFinalWidth, rFinalHeight
      end

      # Check if a Tag is part of the selection
      #
      # Parameters:
      # * *iTagID* (<em>list<String></em>): The Tag ID
      # Return:
      # * _Boolean_: Is the Tag part of the selection ?
      def tagSelected?(iTagID)
        rFound = false

        @SelectedPrimaryTags.each do |iSelectedTagID|
          if (iTagID[0..iSelectedTagID.size - 1] == iSelectedTagID)
            rFound = true
            break
          end
        end

        return rFound
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
        iSerializedTagData.createTag(rRootTag, nil, nil)
      end
      # Deserialize Shortcuts
      lSerializedShortcuts.each do |iSerializedShortcutData|
        lNewShortcut = iSerializedShortcutData.createShortcut(rRootTag, iTypes)
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
    # * *iNewRootTag* (_Tag_): The root Tag that is already merged into the model, and has been created as the root of the  to consider for new ones
    def translateTags(iOldTags, ioNewTags, iNewRootTag)
      iOldTags.each do |iTag, iNil|
        lTagID = iTag.getUniqueID
        # And now we search for the real Tag
        lNewCorrespondingTag = iNewRootTag.searchTag(lTagID)
        if (lNewCorrespondingTag == nil)
          puts "!!! Normally Tag #{lTagID.join('/')} should have been merged in #{iNewRootTag.getUniqueID.join('/')}, but it appears we can't retrieve it after the merge. Ignoring this Tag."
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

    # Get a new Unique ID for Copy/Paste operations
    #
    # Return:
    # * _Integer_: The unique integer
    def getNewCopyID
      # Use a stupid generator, chances are quite thin to have the same results with a seed based on the current time (how can a user perform a cut simultaneously on 2 applications at the same time ?)
      lNow = Time.now
      srand(lNow.sec*1000000+lNow.usec)
      return rand(Float::MAX)
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
