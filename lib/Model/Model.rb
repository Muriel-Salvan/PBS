#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Classes representing the model
  
  # Tags
  class Tag

    # Its name
    #   String
    attr_reader :Name

    # Its parent tag
    #   Tag
    attr_reader :Parent

    # Constructor
    #
    # Parameters:
    # * *iName* (_String_): The name
    # * *iParent* (_Tag_): The parent Tag
    def initialize(iName, iParent)
      @Name = iName
      @Parent = iParent
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
      rTag = Tag.new(@Name.clone, iParentTag)

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

    # Get an ID that is unique for this Tag
    #
    # Return:
    # * _Object_: The Unique ID
    def getUniqueID
      if (@Parent == nil)
        # We are root
        return []
      else
        return @Parent.getUniqueID + [@Name]
      end
    end

    # Get the data ready to be marshalled.
    # This is a recursive method: it serializes all sub Tags also.
    #
    # Return:
    # * _Object_: Data serialized
    def getSerializedData
      lSerializedChildren = []
      @Children.each do |iChildTag|
        lSerializedChildren << iChildTag.getSerializedData
      end
      return [ @Name, lSerializedChildren ]
    end

    # Return the name of a serialized Tag
    #
    # Parameters:
    # * *iSerializedTag* (_Object_): Tag serialized with the getSerializedData method
    # Return:
    # * _String_: Tag's name
    def self.getSerializedTagName(iSerializedTag)
      return iSerializedTag[0]
    end

    # Create a new Tag as a sub-Tag.
    # Check first if it does not already exist.
    #
    # Parameters:
    # * *iName* (_String_): Name of the sub-Tag
    # Return:
    # * _Tag_: The newly created Tag, or nil if it already existed before
    def createSubTag(iName)
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
        rTag = Tag.new(iName, self)
      else
        puts "!!! Tag #{iName}, child of #{self.getUniqueID.join('/')} was already created. Ignoring its new definition."
      end

      return rTag
    end

    # Create a Tag from a serialized one.
    # It is created as a sub Tag of a specified parent Tag (which can be nil).
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The existing parent Tag, or nil if it has no parent Tag
    # * *iSerializedData* (_Object_): The data serialized, as in the getSerializedData method
    # Return:
    # * _Tag_: The newly created Tag
    def self.createTagFromSerializedData(iParentTag, iSerializedData)
      rNewTag = nil

      lName, lSerializedChildren = iSerializedData
      rNewTag = nil
      if (iParentTag != nil)
        rNewTag = iParentTag.createSubTag(lName)
      else
        rNewTag = Tag.new(lName, nil)
      end
      lSerializedChildren.each do |iChildSerializedData|
        Tag.createTagFromSerializedData(rNewTag, iChildSerializedData)
      end

      return rNewTag
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
    end

    # Add a child tag
    # !!! This method has to be used only by the atomic operation dealing with Tags
    #
    # Parameters:
    # * *ioChildTag* (_Tag_): The child Tag
    def addChildTag_UNDO(ioChildTag)
      @Children << ioChildTag
      ioChildTag.Parent = self
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
    # Return:
    # * _Object_: Data serialized
    def getSerializedData
      lTagIDs = []
      @Tags.each do |iTag, iNil|
        lTagIDs << iTag.getUniqueID
      end
      return [ @Type.pluginName, lTagIDs, @Content, @Metadata ]
    end

    # Get the name from a serialized Shortcut data.
    #
    # Parameters:
    # * *iSerializedData* (_Object_): Data serialized
    # Return:
    # * _String_: Name of the Shortcut
    def self.getSerializedShortcutName(iSerializedData)
      return iSerializedData[3]['title']
    end

    # Create a new shortcut from a shortcut serialized data (serialized by getSerializedData.
    # It is assumed that its Tags are already created.
    # It is assumed that its Type exists already.
    #
    # Parameters:
    # * *iRootTag* (_Tag_): The existing root Tag
    # * *iTypes* (<em>map<String,Object></em>): The known types
    # * *iSerializedData* (_Object_): The data serialized, as in the getSerializedData method
    # * *iIgnoreTags* (_Boolean_): Do we ignore Tags ?
    def self.createShortcutFromSerializedData(iRootTag, iTypes, iSerializedData, iIgnoreTags)
      rNewShortcut = nil

      lTypeID, lTagIDs, lContent, lMetadata = iSerializedData
      # Search for the corresponding type
      lType = iTypes[lTypeID]
      if (lType == nil)
        puts "!!! Shortcut has type #{lTypeID} which is unknown. Verify your Shortcut types plugins in the /Types directory. Ignoring this Shortcut."
      else
        lTags = {}
        if (!iIgnoreTags)
          # Search for each Tag
          lTagIDs.each do |iTagID|
            lTag = iRootTag.searchTag(iTagID)
            if (lTag == nil)
              puts "!!! Shortcut has Tag #{iTagID.join('/')} which is unknown. Ignoring this Tag for this Shortcut."
            else
              lTags[lTag] = nil
            end
          end
        end
        rNewShortcut = Shortcut.new(lType, lTags, lContent, lMetadata)
      end

      return rNewShortcut
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

    # Compute a Unique ID based on Content and Metadata.
    # This Unique ID has to depend ONLY on the data of the content and metadata, as it will be used to retrieve different content and metadata cloned.
    #
    # Parameters:
    # * *iContent* (_Content_): The content
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # Return:
    # * _Integer_: The unique ID
    def self.getUniqueID(iContent, iMetadata)
      return Marshal.dump([iContent,iMetadata]).hash
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

  end
  
end
