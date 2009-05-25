#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every method that has to be used by Commands to perform operations on the data
  # Each one of these methods can be used safely: they will be undoable.
  # undoableOperation is useful to create an undoable transaction with a single title (otherwise Undos can be messy for the user, for ex. merging a file can result in tons of undos called 'addShortcut', 'addTag' ...)
  # Each one of those functions should use Undoable Atomic Operations to perform their tasks correctly. Otherwise Undo will not work.
  module Actions

    # Perform an operation, protected with Undo/Redo methods
    #
    # Parameters:
    # * *iOperationTitle* (_String_): Title of the operation to perform to display as undo
    def undoableOperation(iOperationTitle)
      puts "= #{iOperationTitle} ..."
      # Create the current Undo context
      @CurrentUndoableOperation = Controller::UndoableOperation.new(iOperationTitle)
      # Call the command code
      yield
      # Check that the client code effectively modified something before creating an Undo
      if (!@CurrentUndoableOperation.AtomicOperations.empty?)
        # Add it to the Undo stack
        @UndoStack.push(@CurrentUndoableOperation)
        notifyUndoUpdate
        # Clear the Redo stack
        @RedoStack = []
        notifyRedoUpdate
      end
      # Clear the current transaction
      @CurrentUndoableOperation = nil
      puts "= ... #{iOperationTitle}"
    end

    # Modify the shortcut based on new data.
    # Only this method should be used by commands to update a Shortcut's info.
    #
    # Parameters:
    # * *ioSC* (_Shortcut_): The Shortcut to modify
    # * *iNewContent* (_Object_): The new Content
    # * *iNewMetadata* (<em>map<String,Object></em>): The new Metadata
    # * *iNewTags* (<em>map<Tag,nil></em>): The new Tags
    def modifyShortcut(ioSC, iNewContent, iNewMetadata, iNewTags)
      ensureUndoableOperation("Modify Shortcut #{ioSC.Metadata['title']}") do
        if ((ioSC.Content != iNewContent) or
            (ioSC.Metadata != iNewMetadata) or
            (ioSC.Tags != iNewTags))
          atomicOperation(Controller::UAO_ModifySC.new(self, ioSC, iNewContent, iNewMetadata, iNewTags))
        end
      end
    end

    # Change the current file name opened.
    # This also resets the FileModified flag to false.
    #
    # Parameters:
    # * *iNewFileName* (_String_): New file name
    def changeCurrentFileName(iNewFileName)
      ensureUndoableOperation("Change opened file to #{File.basename(iNewFileName)}") do
        atomicOperation(Controller::UAO_ChangeFile.new(self, iNewFileName))
      end
    end

    # Change the current file modified status.
    def setCurrentFileModified
      ensureUndoableOperation('Flag current project as modified') do
        atomicOperation(Controller::UAO_SetFileModified.new(self))
      end
    end

    # Replace completely the Tags and Shortcuts data with a new one
    #
    # Parameters:
    # * *iNewRootTag* (_Tag_): The new root tag
    # * *iNewShortcutsList* (<em>list<Shortcut></em>): The new Shortcuts list
    def replaceCompleteData(iNewRootTag, iNewShortcutsList)
      ensureUndoableOperation('Replace all') do
        atomicOperation(Controller::UAO_ReplaceAll.new(self, iNewRootTag, iNewShortcutsList))
      end
    end

    # Add a new Tag as a child of an existing one.
    # It is assumed the new Tag is not already connected to @RootTag.
    #
    # Parameters:
    # * *ioParentTag* (_Tag_): The Tag that will receive the new one
    # * *iChildTag* (_Tag_): The new Tag to add
    def addNewTag(ioParentTag, iChildTag)
      ensureUndoableOperation("Add Tag #{iChildTag.Name}") do
        atomicOperation(Controller::UAO_AddNewTag.new(self, ioParentTag, iChildTag))
      end
    end

    # Delete a Tag.
    # It also deletes all its sub-Tags.
    # It is assumed that no Shortcut references it any longer before calling this function, as well as any of its Shortcuts.
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to delete
    def deleteTag(iTag)
      ensureUndoableOperation("Delete Tag #{iTag.Name}") do
        atomicOperation(Controller::UAO_DeleteTag.new(self, iTag))
      end
    end

    # Add a new Shortcut.
    # It is assumed that the given Shortcut is not already part of @ShortcutsList.
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): The Shortcut to add
    def addNewShortcut(iShortcut)
      ensureUndoableOperation("Add Shortcut #{iShortcut.Metadata['title']}") do
        atomicOperation(Controller::UAO_AddNewShortcut.new(self, iShortcut))
      end
    end

    # Delete a given Shortcut
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): The Shortcut to delete
    def deleteShortcut(iShortcut)
      ensureUndoableOperation("Delete Shortcut #{iShortcut.Metadata['title']}") do
        atomicOperation(Controller::UAO_DeleteShortcut.new(self, iShortcut))
      end
    end

    # Create a whole Tags' branch, ensuring that a given Tag ID exists.
    #
    # Parameters:
    # * *iTagID* (<em>list<String></em>): The Tag unique ID
    def createTagsBranch(iTagID)
      ensureUndoableOperation("Force Tag #{iTagID[-1]}") do
        lLastExistingTag = @RootTag
        iTagID.each do |iTagName|
          # Check that last existing tag has iTagName as a child
          lTag = nil
          lLastExistingTag.Children.each do |iChildTag|
            if (iChildTag.Name == iTagName)
              # Found it
              lTag = iChildTag
              break
            end
          end
          if (lTag == nil)
            # Create it as a child of lLastExistingTag
            lTag = Tag.new(iTagName, nil)
            addNewTag(lLastExistingTag, lTag)
          end
          lLastExistingTag = lTag
        end
      end
    end

    # Merge a Tag with a another one
    #
    # Parameters:
    # * *ioRootTag* (_Tag_): The root of Tags that will receive new ones. It is assumed that ioRootTag is a child (recursive) of @RootTag.
    # * *iNewRootTag* (_Tag_): The root of Tags that will be merged into ioRootTag.
    def mergeTags(ioRootTag, iNewRootTag)
      ensureUndoableOperation('Merge Tags') do
        # Check each child
        iNewRootTag.Children.each do |iChildTag|
          # First check if it is not already present
          lInitialChildTag = nil
          ioRootTag.Children.each do |iInitialChildTag|
            if (iInitialChildTag.Name == iChildTag.Name)
              lInitialChildTag = iInitialChildTag
              break
            end
          end
          if (lInitialChildTag == nil)
            # This is a new one. Add it simply.
            addNewTag(ioRootTag, iChildTag)
          else
            # Found it. We recursively merge them.
            mergeTags(lInitialChildTag, iChildTag)
          end
        end
      end
    end

    # Merge a new list of Shortcuts into the main one.
    # The new list has references to Tags that "might" not be part already of @RootTag, but it is assumed that the Tags were merged before. Therefore this method will only retrieve Tags based on IDs.
    #
    # Parameters:
    # * *iNewShortcutsList* (<em>list<Shortcut></em>): The list of Shortcuts to be merged into ioShortcuts.
    # * *iNewRootTag* (_Tag_): The merged root Tag of the Shortcuts list. This the Tag in the current data model that has been created as a root to receive the new Shortcuts once merged.
    def mergeShortcuts(iNewShortcutsList, iNewRootTag)
      ensureUndoableOperation('Merge Shortcuts') do
        # Check each Shortcut
        iNewShortcutsList.each do |iSC|
          # First check if it is not already present
          lInitialSC = nil
          @ShortcutsList.each do |iInitialSC|
            if ((iInitialSC.Metadata == iSC.Metadata) and
                (iInitialSC.Content == iSC.Content))
              # We found it
              lInitialSC = iInitialSC
              break
            end
          end
          # Translate its old Tags to the new ones.
          lNewTags = {}
          translateTags(iSC.Tags, lNewTags, iNewRootTag)
          if (lInitialSC == nil)
            # A brand new Shortcut. Add it simply.
            # !!! Here we call replaceTags directly, as it concerns a Shortcut that exists only in this method yet. It is not among @ShortcutsList yet, so no GUI could have any reference on it yet. So it's safe.
            iSC.replaceTags(lNewTags)
            addNewShortcut(iSC)
          else
            # Shortcut is already here. Just merge Tags.
            lNewTags.merge!(lInitialSC.Tags)
            modifyShortcut(lInitialSC, lInitialSC.Content, lInitialSC.Metadata, lNewTags)
          end
        end
      end
    end

    # Add and merge a complete set of Tags and Shortcuts into the main data model
    #
    # Parameters:
    # * *iNewTag* (_Tag_): The Tag of the data we want to add and merge.
    # * *iNewShortcutsList* (<em>list<Shortcut></em>): The Shortcuts list to merge, with Tags references to Tags from iNewTag only.
    # * *iCurrentRootTag* (_Tag_): The current root Tag in which we want to add the new Tag. This is not forcefully the absolute root Tag, in the case we want to merge the data in another Tag (useful for Copy/Paste for example).
    def addMergeTagsShortcuts(iNewTag, iNewShortcutsList, iCurrentRootTag)
      # First check that this Tag does not exist already
      lChildName = iNewTag.Name
      lExistingTag = nil
      iCurrentRootTag.Children.each do |iChildTag|
        if (iChildTag.Name == lChildName)
          lExistingTag = iChildTag
          break
        end
      end
      if (lExistingTag != nil)
        puts "!!! A Tag named #{lChildName} already exists as a sub-Tag of #{iCurrentRootTag.Name}. Merging with existing data."
        # We merge the tags
        mergeTags(lExistingTag, iNewTag)
      else
        # We add the Tag
        addNewTag(iCurrentRootTag, iNewTag)
      end
      # Retrieve the new Tag
      lNewMergedTag = iCurrentRootTag.searchTag([lChildName])
      # Now we merge the Shortcuts
      mergeShortcuts(iNewShortcutsList, lNewMergedTag)
    end

    # Merge serialized Tags and Shortcuts in an existing Tag
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The Tag in which we merge serialized data
    # * *iSerializedTags* (<em>list<Object></em>): The list of serialized Tags, with their sub-Tags and Shortcuts (can be nil for acks)
    # * *iSerializedShortcuts* (<em>list<[Object,String]></em>): The list of serialized Shortcuts, with their parent Tag's ID (can be nil for acks)
    def mergeSerializedTagsShortcuts(iParentTag, iSerializedTags, iSerializedShortcuts)
      # First check each selected Tag
      iSerializedTags.each do |iSerializedTag|
        # Deserialize data in separate objects, ready to be merged after.
        lNewShortcutsList = []
        lNewRootTag = iSerializedTag.createTag(nil, @TypesPlugins, lNewShortcutsList)
        addMergeTagsShortcuts(lNewRootTag, lNewShortcutsList, iParentTag)
      end
      # Then check selected Shortcuts
      if (!iSerializedShortcuts.empty?)
        # Put them in a brand new list first
        lNewShortcuts = []
        iSerializedShortcuts.each do |iSerializedData|
          # Check for already created Shortcuts (in case we selected twice the same Shortcut from different Tags)
          lExistingSC = nil
          lNewID = iSerializedData.getUniqueID
          lNewShortcuts.each do |iExistingSC|
            if (iExistingSC.getUniqueID == lNewID)
              lExistingSC = iExistingSC
              break
            end
          end
          if (lExistingSC != nil)
            # Add lSelectedTag to the list of Tags already part of lExistingSC
            lExistingSC.Tags[iParentTag] = nil
          else
            # A new Shortcut
            lNewShortcut = iSerializedData.createShortcut(nil, @TypesPlugins)
            # Set the Tag
            lNewShortcut.Tags[iParentTag] = nil
            # Add it
            lNewShortcuts << lNewShortcut
          end
        end
        # Then merge Shortcuts
        mergeShortcuts(lNewShortcuts, @RootTag)
      end
    end

  end

end
