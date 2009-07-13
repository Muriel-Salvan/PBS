#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Class that stores a selection of several Tags and Shortcuts alltogether
  class MultipleSelection

    include Tools

    # Class that stores a multiple selection serialized (ready to be marshalled in a file, clipboard...)
    class Serialized

      include Tools

      # Class used to serialize data of a Tag.
      # This class is used to represent the complete data of a Tag, without any reference (other than IDs) to external objects.
      class Tag

        include Tools

        # The name of the Tag
        #    String
        attr_reader :Name

        # The serialized icon of the Tag (or nil if none)
        # TODO (WxRuby): When Wx::Bitmap will have marshal_dump and marshal_load defined, replace the String with the real Wx::Bitmap
        #    String
        attr_reader :Icon

        # The list of serialized sub-Tags IDs
        # Those IDs are relevant only to the MultipleSelection::Serialized object that instantiated this Tag::Serialized object.
        #   list< Integer >
        attr_reader :Children

        # The list of serialized Shortcuts IDs belonging to it
        # Those IDs are relevant only to the MultipleSelection::Serialized object that instantiated this Tag::Serialized object.
        #   list< Integer >
        attr_reader :Shortcuts

        # Constructor
        #
        # Parameters:
        # * *iName* (_String_): The name
        # * *iIcon* (_String_): The icon (or nil if none)
        # * *iChildren* (<em>list<Integer></em>): The list of serialized sub-Tags IDs
        # * *iShortcuts* (<em>list<Integer></em>): The list of serialized Shortcuts IDs
        def initialize(iName, iIcon, iChildren, iShortcuts)
          @Name = iName
          @Icon = iIcon
          @Children = iChildren
          @Shortcuts = iShortcuts
        end

        # Return the name of a serialized Tag
        #
        # Return:
        # * _String_: Tag's name
        def getName
          return @Name
        end

        # Return the simple content to be pasted to the clipboard in case of a single selection of this item.
        #
        # Return:
        # * _String_: The clipboard content
        def getSingleClipContent
          return getName
        end

        # Create a Tag from this serialized one.
        # It is created as a sub Tag of a specified parent Tag (which can be the Root Tag).
        # It then creates recursively all its sub-Tags and associated Shortcuts.
        #
        # Parameters:
        # * *ioController* (_Controller_): The datamodel controller
        # * *iParentTag* (_Tag_): The existing parent Tag, or nil if it has no parent Tag
        # * *iSerializedTags* (<em>map<Integer,MultipleSelection::Serialized::Tag></em>): The list of serialized Tags per ID
        # * *ioShortcutsTags* (<em>map<Integer,map<Tag,nil>></em>): The list of Tags associated to each Shortcut ID. This map can be completed upon new creations.
        def createTag(ioController, iParentTag, iSerializedTags, ioShortcutsTags)
          # Unserialize the icon
          lIcon = nil
          if (@Icon != nil)
            lIcon = Wx::Bitmap.new
            lIcon.setSerialized(@Icon)
          end
          # Create the Tag for real
          lNewTag = ioController.createTag(iParentTag, @Name, lIcon)
          # Create its children
          @Children.each do |iChildTagID|
            lChildSerializedTag = iSerializedTags[iChildTagID]
            if (lChildSerializedTag == nil)
              logBug "Tag ID #{iChildTagID} should be part of the selection, but unable to retrieve it."
            else
              lChildSerializedTag.createTag(ioController, lNewTag, iSerializedTags, ioShortcutsTags)
            end
          end
          # Add ourselves to the list of Tags of each Shortcut that belongs to us
          @Shortcuts.each do |iShortcutID|
            if (ioShortcutsTags[iShortcutID] == nil)
              ioShortcutsTags[iShortcutID] = {}
            end
            ioShortcutsTags[iShortcutID][lNewTag] = nil
          end
        end

      end

      # Class used to serialize data of a Shortcut.
      # This class is used to represent the complete data of a Shortcut, without any reference (other than IDs) to external objects.
      class Shortcut

        include Tools

        # The name of the Type plugin
        #    String
        attr_reader :TypePluginName

        # The content
        #   Object
        attr_reader :Content

        # The metadata
        #   map< String, Object >
        attr_reader :Metadata

        # Constructor
        #
        # Parameters:
        # * *iTypePluginName* (_String_): The Types plugin name
        # * *iContent* (_Object_): The content
        # * *iMetadata* (<em>map<String,Object></em>): The metadata
        def initialize(iTypePluginName, iContent, iMetadata)
          @TypePluginName = iTypePluginName
          @Content = iContent
          @Metadata = iMetadata
        end

        # Get the name of the serialized Shortcut
        #
        # Return:
        # * _String_: The name
        def getName
          return @Metadata['title']
        end

        # Return the simple content to be pasted to the clipboard in case of a single selection of this item.
        #
        # Return:
        # * _String_: The clipboard content
        def getSingleClipContent
          rClipContent = nil

          if (@Content.kind_of?(String))
            rClipContent = @Content.clone
          elsif (@Content.respond_to?(:getSingleClipContent))
            rClipContent = @Content.send(:getSingleClipContent)
          end

          return rClipContent
        end

        # Create a new shortcut from this serialized data.
        # It is assumed that its Tags are already created.
        # It is assumed that its Type exists already.
        #
        # Parameters:
        # * *ioController* (_Controller_): The controller that will receive the new Shortcut
        # * *iTagsSet* (<em>map<Tag,nil></em>): The Tags set to associate this Shortcut to
        def createShortcut(ioController, iTagsSet)
          # TODO (WxRuby): Once marshal_dump and marshal_load are set correctly for Wx::Bitmap, remove the Metadata conversion
          ioController.createShortcut(@TypePluginName, @Content, unserializeMap(@Metadata), iTagsSet)
        end

      end

      # Constructor
      #
      # Parameters:
      # * *iTags* (<em>map<Integer,MultipleSelection::Serialized::Tag></em>): The map of Tags
      # * *iShortcuts* (<em>map<Integer,MultipleSelection::Serialized::Shortcut></em>): The map of Shortcuts
      # * *iSelectedTags* (<em>list<Integer></em>): The list of selected Tags IDs
      # * *iSelectedShortcuts* (<em>list<Integer></em>): The list of selected Shortcuts IDs
      def initialize(iTags, iShortcuts, iSelectedTags, iSelectedShortcuts)
        # Map of serialized Tags, per object_id
        #   map< Integer, MultipleSelection::Serialized::Tag >
        @Tags = iTags
        # Map of serialized Shortcuts, per object_id
        #   map< Integer, MultipleSelection::Serialized::Shortcut >
        @Shortcuts = iShortcuts
        # List of selected Tags IDs
        #   list< Integer >
        @SelectedTags = iSelectedTags
        # List of selected Shortcuts IDs
        #   list< Integer >
        @SelectedShortcuts = iSelectedShortcuts
      end

      # Get the list of serialized Shortcuts involved in this selection
      #
      # Return:
      # * <em>list<MultipleSelection::Serialized::Shortcut></em>: The Shortcuts involved in the selection
      def getSelectedShortcuts
        rShortcuts = []

        @Shortcuts.each do |iID, iSerializedShortcuts|
          rShortcuts << iSerializedShortcuts
        end

        return rShortcuts
      end

      # Get the list of primary selected serialized Tags
      #
      # Return:
      # * <em>list<MultipleSelection::Serialized::Tag></em>: The primary selected Tags
      def getSelectedPrimaryTags
        rTags = []

        @SelectedTags.each do |iTagID|
          rTags << @Tags[iTagID]
        end

        return rTags
      end

      # Get a description from the serialized selection
      #
      # Return:
      # * _String_: The simple description
      def getDescription
        rDescription = nil

        if (@SelectedShortcuts.empty?)
          if (@SelectedTags.empty?)
            rDescription = 'Empty'
          elsif (@SelectedTags.size == 1)
            rDescription = "Tag #{@Tags[@SelectedTags[0]].getName}"
          else
            rDescription = 'Multiple Tags'
          end
        elsif (@SelectedTags.empty?)
          if (@SelectedShortcuts.size == 1)
            rDescription = "Shortcut #{@Shortcuts[@SelectedShortcuts[0]].getName}"
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
      # Return:
      # * _String_: The single content
      def getSingleContent
        rContent = nil

        if (@SelectedShortcuts.empty?)
          if (@SelectedTags.size == 1)
            rContent = @Tags[@SelectedTags[0]].getSingleClipContent
          end
        elsif (@SelectedTags.empty?)
          if (@SelectedShortcuts.size == 1)
            rContent = @Shortcuts[@SelectedShortcuts[0]].getSingleClipContent
          end
        end

        return rContent
      end

      # Create real Tags and Shortcuts in an existing Tag, based on our serialized data.
      # Useful for Open/Paste/Drop...
      #
      # Parameters:
      # * *ioController* (_Controller_): The controller that will have the Tags and Shortcuts created
      # * *iParentTag* (_Tag_): The Tag in which we merge serialized data (can be the Root Tag)
      # * *iLocalSelection* (_MultipleSelection_): The local selection corresponding to this serialized one, or nil if it is from an external source. This is used in case of local selections (Copy/Cut/Paste or Drag/Drop in the same data source), to reuse the same Shortcuts.
      def createSerializedTagsShortcuts(ioController, iParentTag, iLocalSelection)
        # The list of encountered Shortcuts IDs, with the set of Tags associated to them
        # This is computed first in a list, as after gathering Tags/Shortcuts relations, we will create each Shortcut once with its complete list of Tags.
        # map< Integer, map< Tag, nil > >
        lShortcutsTags = {}
        # First create Tags, and fill the relations Shortcuts/Tags.
        @SelectedTags.each do |iTagID|
          lSerializedTag = @Tags[iTagID]
          if (lSerializedTag == nil)
            logBug "Tag of ID #{iTagID} should be part of the serialized data, but unable to retrieve it."
          else
            # Now we can create it
            lSerializedTag.createTag(ioController, iParentTag, @Tags, lShortcutsTags)
          end
        end
        # Then complete the relations Shortcuts/Tags by considering the selected Shortcuts to be created under iParentTag directly.
        @SelectedShortcuts.each do |iShortcutID|
          if (lShortcutsTags[iShortcutID] == nil)
            lShortcutsTags[iShortcutID] = {}
          end
          # For the Root Tag, we leave the list of Tags empty
          if (iParentTag != ioController.RootTag)
            lShortcutsTags[iShortcutID][iParentTag] = nil
          end
        end
        # And now create each Shortcut, knowing its set of Tags
        lShortcutsTags.each do |iShortcutID, iTagsSet|
          # If we are importing from a local source (no external application), we reuse the same Shortcut, and we just modify Tags
          if (iLocalSelection == nil)
            # External source: create from the serialized data completely.
            lSerializedShortcut = @Shortcuts[iShortcutID]
            if (lSerializedShortcut == nil)
              logBug "Normally Shortcut of ID #{iShortcutID} should be part of the serialized selection, but unable to retrieve it."
            else
              lSerializedShortcut.createShortcut(ioController, iTagsSet)
            end
          else
            # Local source: reuse the same Shortcut
            lShortcut = iLocalSelection.SerializedShortcutsIDs[iShortcutID]
            if (lShortcut == nil)
              logBug "Normally Shortcut of ID #{iShortcutID} should be part of the local selection, but unable to retrieve it."
            else
              # Merge Tags
              lNewTags = iTagsSet
              lNewTags.merge!(lShortcut.Tags)
              ioController.updateShortcut(lShortcut, lShortcut.Content, lShortcut.Metadata, lNewTags)
            end
          end
        end
      end

      # Is the serialized selection empty ?
      #
      # Return:
      # * _Boolean_: Is the serialized selection empty ?
      def empty?
        return ((@Tags.empty?) and
                (@Shortcuts.empty?))
      end

    end

    # The list of Tags directly selected
    #   list< Tag >
    attr_reader :SelectedPrimaryTags

    # The list of Tags that are part of the selection because they are a sub-Tag of a primary selected Tag
    #   list< Tag >
    attr_reader :SelectedSecondaryTags

    # The list of Shortcuts directly selected, with their corresponding parent Tag
    #   list< [ Shortcut, Tag ] >
    attr_reader :SelectedPrimaryShortcuts

    # The list of Shortcuts that are part of the selection because they belong to a selected Tag
    #   list< [ Shortcut, Tag ] >
    attr_reader :SelectedSecondaryShortcuts

    # The mapping between IDs used in serialized selection and the real Shortcuts
    # This is valid only if the selection was serialized once
    #   map< Integer, Shortcut >
    attr_reader :SerializedShortcutsIDs

    # Constructor
    #
    # Parameters:
    # * *iController* (_Controller_): The model controller
    def initialize(iController)
      @Controller = iController
      @SerializedSelection = nil
      @SelectedPrimaryShortcuts = []
      @SelectedPrimaryTags = []
      @SelectedSecondaryShortcuts = []
      @SelectedSecondaryTags = []
      @SerializedShortcutsIDs = {}
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
        @SelectedPrimaryTags << iTag
      end
    end

    # Add a Shortcut to the selection
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): The Shortcut
    # * *iParentTag* (_Tag_): The Tag from which the Shortcut was selected (nil for Root)
    def selectShortcut(iShortcut, iParentTag)
      if (iParentTag == nil)
        @SelectedPrimaryShortcuts << [ iShortcut, @Controller.RootTag ]
      else
        @SelectedPrimaryShortcuts << [ iShortcut, iParentTag ]
      end
    end

    # Is the given Tag selected as a primary selection ?
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to check
    # Return:
    # * _Boolean_: Is the given Tag selected as a primary selection ?
    def isTagPrimary?(iTag)
      return @SelectedPrimaryTags.include?(iTag)
    end

    # Is the given Tag selected as a secondary selection ?
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to check
    # Return:
    # * _Boolean_: Is the given Tag selected as a secondary selection ?
    def isTagSecondary?(iTag)
      return @SelectedSecondaryTags.include?(iTag)
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
        return @SelectedPrimaryShortcuts.include?( [ iSC, @Controller.RootTag ] )
      else
        return @SelectedPrimaryShortcuts.include?( [ iSC, iParentTag ] )
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
        return @SelectedSecondaryShortcuts.include?( [ iSC, @Controller.RootTag ] )
      else
        return @SelectedSecondaryShortcuts.include?( [ iSC, iParentTag ] )
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
          lTag = @SelectedPrimaryTags[0]
          if (lTag == nil)
            logBug "Tag #{@SelectedPrimaryTags[0].Name} was selected, but does not exist in the data."
            rDescription = 'Error'
          else
            rDescription = "Tag #{lTag.Name}"
          end
        else
          rDescription = 'Multiple Tags'
        end
      elsif (@SelectedPrimaryTags.empty?)
        if (@SelectedPrimaryShortcuts.size == 1)
          lSC = @SelectedPrimaryShortcuts[0][0]
          if (lSC == nil)
            logBug "Shortcut #{@SelectedPrimaryShortcuts[0][0].Metadata['title']} was selected, but does not exist in the data."
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

    # Get the complete selected data in a serialized way (that is without any references to objects, ready to be marshalled)
    #
    # Return:
    # * <em>MultipleSelection::Serialized</em>: The serialized selection
    def getSerializedSelection
      if (@SerializedSelection == nil)
        computeSerializedSelection
      end
      return @SerializedSelection
    end

    # Add a given Tag to the serialized data
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to add
    # * *ioSerializedTags* (<em>map<Integer,MultipleSelection::Serialized::Tag></em>): The serialized Tags
    def addTagToSerializedData(iTag, ioSerializedTags)
      # Add iTag in the list of Tags if it is not already there
      if (ioSerializedTags[iTag.object_id] == nil)
        # Add it once serialized
        # The icon
        lSerializedIcon = nil
        if (iTag.Icon != nil)
          lSerializedIcon = iTag.Icon.getSerialized
        end
        # The children
        lChildrenIDs = []
        iTag.Children.each do |iChildTag|
          lChildrenIDs << iChildTag.object_id
        end
        # The Shortcuts
        lShortcutsIDs = []
        @SelectedSecondaryShortcuts.each do |iSelectedShortcutInfo|
          iShortcut, iParentTag = iSelectedShortcutInfo
          if (iParentTag == iTag)
            lShortcutsIDs << iShortcut.object_id
          end
        end
        # Add it
        ioSerializedTags[iTag.object_id] = MultipleSelection::Serialized::Tag.new(
          iTag.Name,
          lSerializedIcon,
          lChildrenIDs,
          lShortcutsIDs
        )
      end
    end

    # Add a given Shortcut to the serialized data.
    # Fills @SerializedShortcutsIDs also
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): The Tag to add
    # * *ioSerializedShortcuts* (<em>map<Integer,MultipleSelection::Serialized::Shortcut></em>): The serialized Shortcuts
    def addShortcutToSerializedData(iShortcut, ioSerializedShortcuts)
      # Add iShortcut in the list of Tags if it is not already there
      lShortcutID = iShortcut.object_id
      if (ioSerializedShortcuts[lShortcutID] == nil)
        # Add it
        ioSerializedShortcuts[lShortcutID] = MultipleSelection::Serialized::Shortcut.new(
          iShortcut.Type.pluginName,
          iShortcut.Content,
          serializeMap(iShortcut.Metadata)
        )
        # Fill the correspondance map between IDs and Shortcuts
        @SerializedShortcutsIDs[lShortcutID] = iShortcut
      end
    end

    # Create serialized selection
    def computeSerializedSelection
      # Map of Tags involved in the selection, per ID
      # map< Integer, MultipleSelection::Serialized::Tag >
      lTags = {}
      # Map of Shortcuts involved in the selection, per ID
      # map< Integer, MultipleSelection::Serialized::Shortcut >
      lShortcuts = {}
      # List of selected Tags IDs
      # list< Integer >
      lSelectedTags = []
      # List of selected Shortcuts IDs
      # list< Integer >
      lSelectedShortcuts = []
      # Create the list of serialized Tags
      @SelectedPrimaryTags.each do |iTag|
        addTagToSerializedData(iTag, lTags)
        lSelectedTags << iTag.object_id
      end
      @SelectedSecondaryTags.each do |iTag|
        addTagToSerializedData(iTag, lTags)
      end
      # Create the list of serialized Shortcuts
      @SelectedPrimaryShortcuts.each do |iShortcutInfo|
        iShortcut, iParentTag = iShortcutInfo
        addShortcutToSerializedData(iShortcut, lShortcuts)
        lSelectedShortcuts << iShortcut.object_id
      end
      @SelectedSecondaryShortcuts.each do |iShortcutInfo|
        iShortcut, iParentTag = iShortcutInfo
        addShortcutToSerializedData(iShortcut, lShortcuts)
      end
      @SerializedSelection = MultipleSelection::Serialized.new(
        lTags,
        lShortcuts,
        lSelectedTags,
        lSelectedShortcuts
      )
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
        iSC, iParentTag = iSCInfo
        lTitle = iSC.Metadata['title']
        lWidth, lHeight, lDescent, lLeading = ioDC.get_text_extent(lTitle)
        if (lWidth > rFinalWidth)
          rFinalWidth = lWidth
        end
        ioDC.draw_text(lTitle, 0, rFinalHeight)
        rFinalHeight += lHeight + lLeading
      end
      # Draw Tags
      @SelectedPrimaryTags.each do |iTag|
        lTitle = "#{iTag.Name} ..."
        lWidth, lHeight, lDescent, lLeading = ioDC.get_text_extent(lTitle)
        ioDC.draw_text(lTitle, 0, rFinalHeight)
        if (lWidth > rFinalWidth)
          rFinalWidth = lWidth
        end
        rFinalHeight += lHeight + lLeading
      end

      return rFinalWidth, rFinalHeight
    end

    # Check if a Tag is part of the selection
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag
    # Return:
    # * _Boolean_: Is the Tag part of the selection ?
    def tagSelected?(iTag)
      rFound = false

      (@SelectedPrimaryTags + @SelectedSecondaryTags).each do |iSelectedTag|
        if (iTag == iSelectedTag)
          rFound = true
          break
        end
      end

      return rFound
    end

  end

end
