#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

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

end
