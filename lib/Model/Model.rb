#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Model/MultipleSelection.rb'
# To serialize a bitmap, we need a temporary file
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
    # This constructor should be used ONLY by UOA_* classes to ensure proper Undo/Redo management.
    #
    # Parameters:
    # * *iName* (_String_): The name
    # * *iIcon* (<em>Wx::Bitmap</em>): The icon (can be nil)
    def initialize(iName, iIcon)
      @Name = iName
      @Icon = iIcon
      @Parent = nil
      @Children = []
    end

    # Its children tags
    # Do not use this write accessor except in the constructor of its Children
    #   list< Tag >
    attr_reader :Children

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

    # Get the list of sub-Tags and Shortcuts that belong recursively to us.
    #
    # Parameters:
    # * *iShortcutsList* (<em>list<Shortcut></em>): The Shortcuts list to find which ones belong to us
    # * *oSelectedShortcutsList* (<em>list<[Shortcut,Tag]></em>): The selected Shortcuts list (with the corresponding parent Tag) to be completed
    # * *oSelectedSubTagsList* (<em>list<Tag></em>): The selected sub-Tags list to be completed
    def getSecondaryObjects(iShortcutsList, oSelectedShortcutsList, oSelectedSubTagsList)
      # The children
      @Children.each do |iChildTag|
        oSelectedSubTagsList << iChildTag
        iChildTag.getSecondaryObjects(iShortcutsList, oSelectedShortcutsList, oSelectedSubTagsList)
      end
      # The Shortcuts
      iShortcutsList.each do |iSC|
        if (iSC.Tags.has_key?(self))
          # We take this one with us
          oSelectedShortcutsList << [ iSC, self ]
        end
      end
    end

    # !!! Following methods have to be used ONLY by UAO_* classes.
    # !!! This is the only way to ensure that Undo/Redo management will behave correctly.

    # Set the Parent's Tag
    # !!! This method has to be used only by the atomic operation dealing with Tags
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The parent Tag
    def _UNDO_setParent(iParentTag)
      @Parent = iParentTag
    end

    # Add a child Tag
    # !!! This method has to be used only by the atomic operation dealing with Tags to ensure proper Undo/Redo management.
    #
    # Parameters:
    # * *iChildTag* (_Tag_): The child Tag
    def _UNDO_addChild(iChildTag)
      iChildTag._UNDO_setParent(self)
      @Children << iChildTag
    end

    # Delete a given sub Tag.
    # !!! This method has to be used only by the atomic operation dealing with Tags to ensure proper Undo/Redo management.
    #
    # Parameters:
    # * *iChildTagToDelete* (_Tag_): The child Tag to delete
    def _UNDO_deleteChild(iChildTagToDelete)
      @Children.delete_if do |iChildTag|
        if (iChildTag == iChildTagToDelete)
          iChildTag._UNDO_setParent(nil)
          true
        else
          false
        end
      end
    end

    # Set the name.
    # !!! This method has to be used only by the atomic operation dealing with Tags to ensure proper Undo/Redo management.
    #
    # Parameters:
    # * *iNewName* (_String_): The new name
    def _UNDO_setName(iNewName)
      @Name = iNewName
    end

    # Set the icon.
    # !!! This method has to be used only by the atomic operation dealing with Tags to ensure proper Undo/Redo management.
    #
    # Parameters:
    # * *iNewIcon* (<em>Wx::Bitmap</em>): The new icon (can be nil)
    def _UNDO_setIcon(iNewIcon)
      @Icon = iNewIcon
    end

    # Set the sub-Tags of the Tag. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewSubTags* (<em>list<Tag></em>): The new sub-Tags
    # Return:
    # * <em>map<Tag, list<Tag>></em>: The map of parent Tag changed with their old sub-Tags list
    def _UNDO_setSubTags(iNewSubTags)
      rChangedParents = {}

      # First, delete all our current sub-Tags not part of iNewSubTags
      @Children.delete_if do |iChildTag|
        if (!iNewSubTags.include?(iChildTag))
          iChildTag._UNDO_setParent(nil)
          true
        else
          false
        end
      end
      # Then add all sub-Tags that are not part yet of @Children
      iNewSubTags.each do |iNewSubTag|
        # First check if this sub-Tag is already part of the children
        if (!@Children.include?(iNewSubTag))
          # Remove it from its current parent
          lOldParentTag = iNewSubTag.Parent
          if (rChangedParents[lOldParentTag] == nil)
            rChangedParents[lOldParentTag] = lOldParentTag.Children.clone
          end
          lOldParentTag._UNDO_deleteChild(iNewSubTag)
          # Add it to our children list
          _UNDO_addChild(iNewSubTag)
        end
      end

      return rChangedParents
    end

  end

  # Shortcuts
  class Shortcut

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
    # This constructor should be used ONLY by UOA_* classes to ensure proper Undo/Redo management.
    #
    # Parameters:
    # * *iType* (_Type_): The type
    # * *iContent* (_Object_): The content
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # * *iTags* (<em>map<Tag,nil></em>): The Tags
    def initialize(iType, iContent, iMetadata, iTags)
      @Type = iType
      @Content = iContent
      @Metadata = iMetadata
      @Tags = iTags
    end

    # Get the summary of its content.
    # This could be used in tool tips for example.
    #
    # Return:
    # * _String_: The content's summary
    def getContentSummary
      @Type.getContentSummary(@Content)
    end

    # Dump the Shortcut's info
    def dump
      puts "+-Content: #{@Content.inspect}"
      puts '+-Metadata:'
      @Metadata.each do |iKey, iValue|
        puts "| +-#{iKey}: #{iValue}"
      end
      puts '+-Tags:'
      @Tags.each do |iTag, iNil|
        puts "  +-#{iTag.Name}"
      end
    end

    # !!! Following methods have to be used ONLY by UAO_* classes.
    # !!! This is the only way to ensure that Undo/Redo management will behave correctly.

    # Set the content of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewContent* (_Object_): The new content
    def _UNDO_setContent(iNewContent)
      @Content = iNewContent
    end

    # Set the metadata of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewMetadata* (<em>map<String,Object></em>): The new metadata
    def _UNDO_setMetadata(iNewMetadata)
      @Metadata = iNewMetadata
    end

    # Set the tags of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters:
    # * *iNewTags* (<em>map<Tag,nil></em>): The new tags
    def _UNDO_setTags(iNewTags)
      # Remove Tags that are not part of the new list
      @Tags.delete_if do |iTag, iNil|
        !iNewTags.has_key?(iTag)
      end
      # Add Tags that are not part of the current list
      iNewTags.each do |iTag, iNil|
        @Tags[iTag] = nil
      end
    end

  end
  
end
