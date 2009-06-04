#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'tmpdir'

# It is impossible to marshal_load a Wx::Bitmap using load_file, as the C-type is checked during load_file call and the Marshaller does not create exactly the same C-type between 2 executions.
# Therefore we have 2 alternatives:
# 1. give an external way (no more marshal_dump/marshal_load) to serialize a bitmap with load_file (the one we are doing here)
# 2. don't use load_file to get the content back during marshal_load. Unfortunately Wx::Bitmap does not have any other method (or maybe using Wx::Image ?).
# TODO (WxRuby): Implement Wx::Bitmap::marshal_dump and Wx::Bitmap::marshal_load
# TODO (WxRuby): Implement Wx::Bitmap::<=> and Wx::Bitmap.eql? and remove current home-made implementation
module Wx

  class Bitmap

    # Get the serialized content.
    # Equivalent to marshal_dump (could be renamed if only load_file could work)
    #
    # Return:
    # * _String_: The serialized content
    def getSerialized
      rData = ''

      # Require a temporary file
      lFileName = "#{Dir.tmpdir}/#{object_id}.png"
      if (save_file(lFileName, Wx::BITMAP_TYPE_PNG))
        File.open(lFileName, 'rb') do |iFile|
          rData = iFile.read
        end
        File.unlink(lFileName)
      else
        puts "!!! Error while loading data from temporary file: #{lFileName}."
      end

      return rData
    end

    # Set the content based on a serialized one
    # Equivalent to marshal_load (could be renamed if only load_file could work)
    #
    # Parameters:
    # * *iData* (_String_): The serialized content
    def setSerialized(iData)
      # Require a temporary file
      lFileName = "#{Dir.tmpdir}/#{object_id}.png"
      File.open(lFileName, 'wb') do |oFile|
        oFile.write(iData)
      end
      if (load_file(lFileName, Wx::BITMAP_TYPE_PNG))
        File.unlink(lFileName)
      else
        puts "!!! Error while loading data from temporary file: #{lFileName}."
      end
    end

    # Compares 2 different bitmaps
    # It stores results in a cache to speed up comparisons
    #
    # Parameters:
    # * *iOtherBitmap* (<em>Wx::Bitmap</em>): The other bitmap to compare
    # Return:
    # * _Integer_: The comparison (self - iOtherBitmap)
    def <=>(iOtherBitmap)
      if (!defined?(@CacheDataCompare))
        # The cache: For each bitmap's object id, the comparison
        # map< Integer, Integer >
        @CacheDataCompare = {}
      end
      if (@CacheDataCompare[iOtherBitmap.object_id] == nil)
        # Perform the comparison of the data
        @CacheDataCompare[iOtherBitmap.object_id] = self.convert_to_image.data.<=>(iOtherBitmap.convert_to_image.data)
      end

      return @CacheDataCompare[iOtherBitmap.object_id]
    end

    # Is the given bitmap equal to ourselves ?
    #
    # Parameters:
    # * *iOtherBitmap* (<em>Wx::Bitmap</em>): The other bitmap to compare
    # Return:
    # * _Boolean_: Is the given bitmap equal to ourselves ?
    def ==(iOtherBitmap)
      return ((self.object_id == iOtherBitmap.object_id) or
              ((self.class == iOtherBitmap.class) and
               (self.<=>(iOtherBitmap) == 0)))
    end

  end

end

module PBS

  # Classes representing the model
  
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

  # Tags
  class Tag

    # Class used to serialize data of a Tag.
    # This class is used to represent the complete data of a Tag, without any reference (other than IDs) to external objects.
    class Serialized

      # The name of the Tag
      #    String
      attr_reader :Name

      # The serialized icon of the Tag (or nil if none)
      # TODO (WxRuby): When Wx::Bitmap will have marshal_dump and marshal_load defined, replace the String with a Wx::Bitmap
      #    String
      attr_reader :Icon

      # The list of serialized sub-Tags
      #   list< Serialized >
      attr_reader :Children

      # The list of serialized Shortcuts belonging to it
      #   list< Object >
      attr_reader :Shortcuts

      # Constructor
      #
      # Parameters:
      # * *iName* (_String_): The name
      # * *iIcon* (_String_): The icon (or nil if none)
      # * *iChildren* (<em>list<Serialized></em>): The list of serialized sub-Tags
      # * *iShortcuts* (<em>list<Object></em>): The list of serialized Shortcuts
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
      # It is created as a sub Tag of a specified parent Tag (which can be nil).
      #
      # Parameters:
      # * *iParentTag* (_Tag_): The existing parent Tag, or nil if it has no parent Tag
      # * *iShortcutTypes* (<em>map<String,Object></em>): The set of Types plugins, or nil if we don't want to instantiate Shortcuts)
      # * *ioShortcutsList* (<em>list<Shortcut></em>): The list of Shortcuts to complete with the ones attached to this Tag. This parameter is ignored if iShortcutTypes is nil.
      # Return:
      # * _Tag_: The newly created Tag
      def createTag(iParentTag, iShortcutTypes, ioShortcutsList)
        rNewTag = nil

        # Unserialize the icon
        lIcon = nil
        if (@Icon != nil)
          lIcon = Wx::Bitmap.new
          lIcon.setSerialized(@Icon)
        end
        # Create the Tag for real
        if (iParentTag != nil)
          rNewTag = iParentTag.createSubTag(@Name, lIcon)
        else
          rNewTag = Tag.new(@Name, lIcon, nil)
        end
        # Create its children
        @Children.each do |iChildSerializedData|
          iChildSerializedData.createTag(rNewTag, iShortcutTypes, ioShortcutsList)
        end
        # Create its Shortcuts
        if ((@Shortcuts != nil) and
            (iShortcutTypes != nil))
          @Shortcuts.each do |iSerializedShortcut|
            # First check if this serialized Shortcut is already present in the Shortcuts list
            lExistingSC = nil
            lNewUniqueID = iSerializedShortcut.getUniqueID
            ioShortcutsList.each do |iExistingSC|
              if (iExistingSC.getUniqueID == lNewUniqueID)
                # Found it
                lExistingSC = iExistingSC
                break
              end
            end
            if (lExistingSC != nil)
              # There is already a Shortcut. Just add this Tag among its ones.
              lExistingSC.Tags[rNewTag] = nil
            else
              # Create a new Shortcut.
              lNewShortcut = iSerializedShortcut.createShortcut(nil, iShortcutTypes)
              # Set the new Tag as its only one.
              lNewShortcut.Tags[rNewTag] = nil
              # Add it to the list.
              ioShortcutsList << lNewShortcut
            end
          end
        end

        return rNewTag
      end

    end

    # Its name
    #   String
    attr_reader :Name

    # Its icon (can be nil if none)
    #   Wx::Bitmap
    attr_reader :Icon

    # Its parent tag
    #   Tag
    attr_reader :Parent

    # Constructor
    #
    # Parameters:
    # * *iName* (_String_): The name
    # * *iIcon* (<em>Wx::Bitmap</em>): The icon (can be nil if none)
    # * *iParent* (_Tag_): The parent Tag
    def initialize(iName, iIcon, iParent)
      @Name = iName
      @Icon = iIcon
      @Parent = iParent
      @UniqueID = nil
      @Children = []
      if (iParent != nil)
        iParent.Children << self
      end
    end

    # Clone this Tag, giving another parent.
    # This method also clones each child.
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The parent Tag
    # Return:
    # * _Tag_: The clone
    def clone(iParentTag)
      lIconClone = nil
      if (@Icon != nil)
        lIconClone = @Icon.clone
      end
      rTag = Tag.new(@Name.clone, lIconClone, iParentTag)
      @Children.each do |iChildTag|
        iChildTag.clone(rTag)
      end
      
      return rTag
    end

    # Its children tags
    # Do not use this write accessor except in the constructor of its Children
    #   list< Tag >
    attr_reader :Children

    # Recursive iterator among the tag's children.
    #
    # Parameters:
    # * *CodeBlock*: The code called for each tag found.
    # ** *iTag* (_Tag_): The tag being iterated on.
    def traverse
      @Children.each do |iChildTag|
        # It is important to traverse this level before its children.
        # The serialization counts on this property, as we must first create parent Tags before children.
        yield(iChildTag)
        iChildTag.traverse do |iChildChildTag|
          yield(iChildChildTag)
        end
      end
    end

    # Is this Tag a sub-Tag of another one ?
    #
    # Parameters:
    # * *iOtherTag* (_Tag_): The other Tag
    # Return:
    # * _Boolean_: Is this Tag a sub-Tag of another one ?
    def subTagOf?(iOtherTag)
      rFound = false

      lCheckTag = @Parent
      while (lCheckTag != nil)
        if (lCheckTag == iOtherTag)
          rFound = true
          break
        end
        lCheckTag = lCheckTag.Parent
      end

      return rFound
    end

    # Get an ID that is unique for this Tag
    #
    # Return:
    # * _Object_: The Unique ID
    def getUniqueID
      if (@UniqueID == nil)
        # Compute it first
        if (@Parent == nil)
          # We are root
          @UniqueID = []
        else
          @UniqueID = @Parent.getUniqueID + [@Name]
        end
      end
      return @UniqueID
    end

    # Get the data ready to be marshalled.
    # This is a recursive method: it serializes all sub Tags also.
    #
    # Return:
    # * _Serialized_: Data serialized
    def getSerializedData
      lSerializedChildren = []
      @Children.each do |iChildTag|
        lSerializedChildren << iChildTag.getSerializedData
      end
      lSerializedIcon = nil
      if (@Icon != nil)
        lSerializedIcon = @Icon.getSerialized
      end
      return Serialized.new(@Name, lSerializedIcon, lSerializedChildren, nil)
    end

    # Get the list of sub-Tags and Shortcuts that belong recursively to us.
    #
    # Parameters:
    # * *iShortcutsList* (<em>list<Shortcut></em>): The Shortcuts list to find which ones belong to us
    # * *oSelectedShortcutsList* (<em>list<[Integer,list<String>]></em>): The selected Shortcuts IDs list (with the corresponding parent Tag ID) to be completed
    # * *oSelectedSubTagsList* (<em>list<list<String>></em>): The selected sub-Tags ID's list to be completed
    def getSecondaryObjects(iShortcutsList, oSelectedShortcutsList, oSelectedSubTagsList)
      # The children
      @Children.each do |iChildTag|
        oSelectedSubTagsList << iChildTag.getUniqueID
        iChildTag.getSecondaryObjects(iShortcutsList, oSelectedShortcutsList, oSelectedSubTagsList)
      end
      # The Shortcuts
      iShortcutsList.each do |iSC|
        if (iSC.Tags.has_key?(self))
          # We take this one with us
          oSelectedShortcutsList << [ iSC.getUniqueID, getUniqueID ]
        end
      end
    end

    # Get the data ready to be marshalled, including Shortcuts belonging to this Tag.
    # This is a recursive method: it serializes all sub Tags also.
    #
    # Parameters:
    # * *iShortcutsList* (<em>list<Shortcut></em>): The Shortcuts list to find which ones belong to us
    # Return:
    # * _Serialized_: Data serialized
    def getSerializedDataWithShortcuts(iShortcutsList)
      # The children
      lSerializedChildren = []
      @Children.each do |iChildTag|
        lSerializedChildren << iChildTag.getSerializedDataWithShortcuts(iShortcutsList)
      end
      # The Shortcuts
      lSerializedSCs = []
      iShortcutsList.each do |iSC|
        if (iSC.Tags.has_key?(self))
          # We take this one with us
          lSerializedSCs << iSC.getSerializedData(true)
        end
      end
      lSerializedIcon = nil
      if (@Icon != nil)
        lSerializedIcon = @Icon.getSerialized
      end
      return Serialized.new(@Name, lSerializedIcon, lSerializedChildren, lSerializedSCs)
    end

    # Create a new Tag as a sub-Tag.
    # Check first if it does not already exist.
    #
    # Parameters:
    # * *iName* (_String_): Name of the sub-Tag
    # * *iIcon* (<em>Wx::Bitmap</em>): Icon of the sub-Tag (can be nil if none)
    # Return:
    # * _Tag_: The newly created Tag, or nil if it already existed before
    def createSubTag(iName, iIcon)
      rTag = nil

      # First check that it does not exist already
      lFound = false
      @Children.each do |iChildTag|
        if (iChildTag.Name == iName)
          lFound = true
          break
        end
      end
      if (!lFound)
        rTag = Tag.new(iName, iIcon, self)
      else
        puts "!!! Tag #{iName}, child of #{getUniqueID.join('/')} was already created. Ignoring its new definition."
      end

      return rTag
    end

    # Search for a given Tag recursively, among children.
    #
    # Parameters:
    # * *iTagID* (<em>list<String></em>): The Tag ID, relative to the current Tag
    # Return:
    # * _Tag_: The corresponding Tag if found, nil otherwise
    def searchTag(iTagID)
      rFoundTag = nil

      if (iTagID.empty?)
        # It is us
        rFoundTag = self
      else
        lName = iTagID[0]
        @Children.each do |iChildTag|
          if (iChildTag.Name == lName)
            # Found the path through our children
            rFoundTag = iChildTag.searchTag(iTagID[1..-1])
            break
          end
        end
      end

      return rFoundTag
    end

    # Set the Parent's Tag
    # !!! This method has to be used only by the atomic operation dealing with Tags
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The parent Tag
    def setParent_UNDO(iParentTag)
      @Parent = iParentTag
      resetUniqueIDs
    end

    # Reset Unique IDs of this Tag and all its children.
    # This is used when changing a parent Tag somewhere in the branch.
    def resetUniqueIDs
      @UniqueID = nil
      # Reset also UniqueIDs of every child
      @Children.each do |iChildTag|
        iChildTag.resetUniqueIDs
      end
    end

    # Delete a given child name.
    # !!! This method has to be used only by the atomic operation dealing with Tags
    #
    # Parameters:
    # * *iChildName* (_String_): The child name to delete
    def deleteChildTag_UNDO(iChildName)
      @Children.delete_if do |iChildTag|
        if (iChildTag.Name == iChildName)
          iChildTag.setParent_UNDO(nil)
          true
        else
          false
        end
      end
    end

    # Set the name. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewName* (_String_): The new name
    def setName_UNDO(iNewName)
      @Name = iNewName
      resetUniqueIDs
    end

    # Set the icon. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewIcon* (<em>Wx::Bitmap</em>): The new icon (can be nil)
    def setIcon_UNDO(iNewIcon)
      @Icon = iNewIcon
    end

  end

  # Shortcuts
  class Shortcut

    # Class used to serialize data of a Shortcut.
    # This class is used to represent the complete data of a Shortcut, without any reference (other than IDs) to external objects.
    class Serialized

      # The name of the Type plugin
      #    String
      attr_reader :TypePluginName

      # The IDs of the Tags
      #   list< list< String > >
      attr_reader :TagsIDs

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
      # * *iTagsIDs* (<em>list<list<String>></em>): The list of Tags IDs
      # * *iContent* (_Object_): The content
      # * *iMetadata* (<em>map<String,Object></em>): The metadata
      def initialize(iTypePluginName, iTagsIDs, iContent, iMetadata)
        @TypePluginName = iTypePluginName
        @TagsIDs = iTagsIDs
        @Content = iContent
        @Metadata = iMetadata
      end

      # Clone this serialized data
      #
      # Return:
      # * <em>Shortcut::Serialized</em>: The clone
      def clone
        return Serialized.new(@TypePluginName, @TagsIDs.clone, @Content.clone, @Metadata.clone)
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

      # Get the unique ID of the serialized Shortcut
      #
      # Return:
      # * _Integer_: The unique ID
      def getUniqueID
        return Shortcut.getUniqueID(@Content, @Metadata)
      end

      # Create a new shortcut from this serialized data.
      # It is assumed that its Tags are already created.
      # It is assumed that its Type exists already.
      #
      # Parameters:
      # * *iRootTag* (_Tag_): The existing root Tag (if nil, we ignore the Tags: the created Tags set will be empty)
      # * *iTypes* (<em>map<String,Object></em>): The known types
      # Return:
      # * _Shortcut_: The resulting Shortcut
      def createShortcut(iRootTag, iTypes)
        rNewShortcut = nil

        # Search for the corresponding type
        lType = iTypes[@TypePluginName]
        if (lType == nil)
          puts "!!! Shortcut has type #{@TypePluginName} which is unknown. Verify your Shortcut types plugins in the /Types directory. Ignoring this Shortcut."
        else
          lTags = {}
          if (iRootTag != nil)
            # Search for each Tag
            @TagsIDs.each do |iTagID|
              lTag = iRootTag.searchTag(iTagID)
              if (lTag == nil)
                puts "!!! Shortcut has Tag #{iTagID.join('/')} which is unknown. Ignoring this Tag for this Shortcut."
              else
                lTags[lTag] = nil
              end
            end
          end
          # TODO (WxRuby): Once marshal_dump and marshal_load are set correctly for Wx::Bitmap, uncomment next line and remove remaining ones.
          #rNewShortcut = Shortcut.new(lType, lTags, @Content, @Metadata)
          rNewShortcut = Shortcut.new(lType, lTags, @Content, Shortcut.setSerializableMetadata(@Metadata))
        end

        return rNewShortcut
      end

    end

    # The type
    #   Object
    attr_reader :Type

    # The set of tags this Shortcut belongs to
    #   map< Tag, nil >
    attr_reader :Tags

    # The content, type dependent
    #   Object
    attr_reader :Content

    # The metadata, used by integration plugins. It is a map of values (see this as properties)
    #   map< String, Object >
    attr_reader :Metadata

    # Constructor
    #
    # Parameters:
    # * *iType* (_Type_): The type
    # * *iTags* (<em>map<Tag,nil></em>): Set of tags
    # * *iContent* (_Object_): Content (type specific)
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    def initialize(iType, iTags, iContent, iMetadata)
      @Type = iType
      @Tags = iTags
      @Content = iContent
      @Metadata = iMetadata
      # Initialize attributes of Metadata that are not set, as it will be useful to compare them.
      # In short terms, we want to have { 'title' => 'ok' } == { 'title' => 'ok', 'icon' => nil }
      [ 'title', 'icon' ].each do |iKey|
        if (!@Metadata.has_key?(iKey))
          @Metadata[iKey] = nil
        end
      end
      computeUniqueID
    end

    # Clone.
    #
    # Return:
    # * _Shortcut_: The clone
    def clone
      return Shortcut.new(@Type, @Tags.clone, @Content.clone, @Metadata.clone)
    end

    # Compute this Shortcut's unique ID
    def computeUniqueID
      # The Unique ID HAS TO BE recomputed each time @Content or @Metadata has been modified.
      @UniqueID = Shortcut.getUniqueID(@Content, @Metadata)
    end

    # Get the data ready to be marshalled.
    # This is used internally by Save/Undo operations
    #
    # Parameters:
    # * *iIgnoreTags* (_Boolean_): Do we ignore Tags ? [optional = false]
    # Return:
    # * <em>Shortcut::Serialized</em>: Data serialized
    def getSerializedData(iIgnoreTags = false)
      lTagIDs = []
      if (!iIgnoreTags)
        @Tags.each do |iTag, iNil|
          lTagIDs << iTag.getUniqueID
        end
      end
      # TODO (WxRuby): Once marshal_dump and marshal_load are set correctly for Wx::Bitmap, uncomment next line and remove remaining ones.
      #return Serialized.new(@Type.pluginName, lTagIDs, @Content, @Metadata)
      return Serialized.new(@Type.pluginName, lTagIDs, @Content, Shortcut.getSerializableMetadata(@Metadata))
    end

    # Replace Tags with new ones.
    #
    # Parameters:
    # * *iNewTags* (<em>map<Tag,nil></em>): The new Tags
    def replaceTags(iNewTags)
      # Remove Tags that are not part of the new list
      @Tags.delete_if do |iTag, iNil|
        !iNewTags.has_key?(iTag)
      end
      # Add Tags that are not part of the current list
      iNewTags.each do |iTag, iNil|
        @Tags[iTag] = nil
      end
    end

    # Get a Unique ID for this Shortcut.
    # Beware as this ID changes as soon as the Content or the Metadata changes.
    # Return:
    # * _Integer_: The unique ID
    def getUniqueID
      return @UniqueID
    end

    # Return the serializable Metadata
    # It converts any Wx::Bitmap to its string representation.
    # TODO (WxRuby): Remove this method once marshal_dump and marshal_load have been implemented in Wx::Bitmap.
    #
    # Parameters:
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # Return:
    # * <em>map<String,Object></em>: The serializable metadata
    def self.getSerializableMetadata(iMetadata)
      rSerializableMetadata = {}

      iMetadata.each do |iKey, iValue|
        if (iValue.is_a?(Wx::Bitmap))
          rSerializableMetadata[iKey] = [ Wx::Bitmap, iValue.getSerialized ]
        else
          rSerializableMetadata[iKey] = iValue
        end
      end

      return rSerializableMetadata
    end

    # Return a Metadata from a serialized one.
    # TODO (WxRuby): Remove this method once marshal_dump and marshal_load have been implemented in Wx::Bitmap.
    def self.setSerializableMetadata(iSerializedMetadata)
      rMetadata = {}

      iSerializedMetadata.each do |iKey, iValue|
        if ((iValue.is_a?(Array)) and
            (iValue.size == 2) and
            (iValue[0] == Wx::Bitmap))
          lBitmap = Wx::Bitmap.new
          lBitmap.setSerialized(iValue[1])
          rMetadata[iKey] = lBitmap
        else
          rMetadata[iKey] = iValue
        end
      end

      return rMetadata
    end

    # Compute a Unique ID based on Content and Metadata.
    # !!! This Unique ID has to depend ONLY on the data of the content and metadata, as it will be used to retrieve different content and metadata cloned.
    # !!! It HAS TO depend on BOTH the complete content and complete metadata also, as otherwise we will find doublons everywhere.
    #
    # Parameters:
    # * *iContent* (_Content_): The content
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # Return:
    # * _Integer_: The unique ID
    def self.getUniqueID(iContent, iMetadata)
      # TODO (WxRuby): Once marshal_dump and marshal_load are set correctly for Wx::Bitmap, uncomment next line and remove remaining ones.
      #return Marshal.dump( [ iContent, iMetadata ] ).hash
      # Now we have to convert every Wx::Bitmap data from the metadata before.
      return Marshal.dump( [ iContent, Shortcut.getSerializableMetadata(iMetadata) ] ).hash
    end

    # Set the content of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewContent* (_Object_): The new content
    def setContent_UNDO(iNewContent)
      @Content = iNewContent
      computeUniqueID
    end

    # Set the metadata of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewMetadata* (<em>map<String,Object></em>): The new metadata
    def setMetadata_UNDO(iNewMetadata)
      @Metadata = iNewMetadata
      computeUniqueID
    end

    # Set the tags of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewTags* (<em>map<Tag,nil></em>): The new tags
    def setTags_UNDO(iNewTags)
      replaceTags(iNewTags)
    end

    # Dump the Shortcut's info
    def dump
      puts "+-ID: #{getUniqueID}"
      puts "+-Content: #{@Content.inspect}"
      puts '+-Metadata:'
      @Metadata.each do |iKey, iValue|
        puts "| +-#{iKey}: #{iValue}"
      end
      puts '+-Tags:'
      @Tags.each do |iTag, iNil|
        puts "  +-#{iTag.getUniqueID.join('/')}"
      end
    end

  end
  
end
