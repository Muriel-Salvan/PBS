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
      # Reset the transaction error
      @CurrentTransactionErrors = []
      @CurrentTransactionToBeCancelled = false
      # Call the command code
      yield
      # Check possible errors
      if (!@CurrentTransactionErrors.empty?)
        # Display errors
        showModal(Wx::MessageDialog, nil,
          @CurrentTransactionErrors.join("\n"),
          "Errors during #{iOperationTitle}",
          :style => Wx::OK
        ) do |iModalResult, iDialog|
          # Nothing to do
        end
      end
      # Check that the client code effectively modified something before creating an Undo
      if (!@CurrentUndoableOperation.AtomicOperations.empty?)
        # If we want to cancel the whole operation, do it now
        if (@CurrentTransactionToBeCancelled)
          # Rollback everything
          @CurrentUndoableOperation.undo
        else
          # Add it to the Undo stack
          @UndoStack.push(@CurrentUndoableOperation)
          notifyUndoUpdate
          # Clear the Redo stack
          @RedoStack = []
          notifyRedoUpdate
        end
      end
      # Clear the current transaction
      @CurrentUndoableOperation = nil
      puts "= ... #{iOperationTitle}"
    end

    # Create a Tag if it does not exist already, and return it.
    # This method is protected for Undo/Redo management.
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The parent Tag
    # * *iTagName* (_String_): The new Tag name
    # * *iIcon* (<em>Wx::Bitmap</em>): The icon (can be nil)
    # Return:
    # * _Tag_: The created Tag.
    def createTag(iParentTag, iTagName, iIcon)
      rTag = nil

      ensureUndoableOperation("Create Tag #{iTagName}") do
        rTag, lAction = checkTagUnicity(iParentTag, iTagName, iIcon)
        if ((rTag == nil) or
            (lAction == ID_KEEP))
          # OK, create it
          rTag = atomicOperation(Controller::UAO_CreateTag.new(self, iParentTag, iTagName, iIcon))
          setCurrentFileModified
        end
      end

      return rTag
    end

    # Delete a Tag.
    # It also deletes all its sub-Tags.
    # It is assumed that no Shortcut references it any longer before calling this function, as well as any of its sub-Tags.
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to delete
    def deleteTag(iTag)
      ensureUndoableOperation("Delete Tag #{iTag.Name}") do
        atomicOperation(Controller::UAO_DeleteTag.new(self, iTag))
        setCurrentFileModified
      end
    end

    # Modify the Tag based on new data.
    # Only this method should be used by commands to update a Tag's info.
    #
    # Parameters:
    # * *ioTag* (_Tag_): The Tag to modify
    # * *iNewName* (_String_): The new name
    # * *iNewIcon* (<em>Wx::Bitmap</em>): The new icon (can be nil)
    # * *iNewChildren* (<em>list<Tag></em>): The new list of sub-Tags
    # Return:
    # * _Boolean_: Did the data effectively changed ? (It will also be true if the update resulted in a delete of the Tag)
    def updateTag(ioTag, iNewName, iNewIcon, iNewChildren)
      rChanged = false

      if ((ioTag.Name != iNewName) or
          (ioTag.Icon != iNewIcon))
        ensureUndoableOperation("Update Tag #{ioTag.Name}") do
          lDoublon, lAction = checkTagUnicity(ioTag.Parent, iNewName, iNewIcon, ioTag)
          if ((lDoublon == nil) or
              (lAction == ID_KEEP))
            atomicOperation(Controller::UAO_UpdateTag.new(self, ioTag, iNewName, iNewIcon, iNewChildren))
            setCurrentFileModified
            rChanged = true
          elsif (lAction == ID_MERGE)
            # We have to change the children and the Shortcuts belonging to ioTag, to make them belonging to lDoublon
            # Change Shortcuts first
            @ShortcutsList.each do |ioShortcut|
              if (ioShortcut.Tags.has_key?(ioTag))
                lNewTags = ioShortcut.Tags.clone
                lNewTags.delete(ioTag)
                lNewTags[lDoublon] = nil
                updateShortcut(ioShortcut, ioShortcut.Content, ioShortcut.Metadata, lNewTags)
              end
            end
            # Change Tags then in the doublon
            lNewChildren = ioTag.Children.clone
            lNewChildren += lDoublon.Children
            atomicOperation(Controller::UAO_UpdateTag.new(self, lDoublon, lDoublon.Name, lDoublon.Icon, lNewChildren))
            setCurrentFileModified
            # And now we delete ioTag
            deleteTag(ioTag)
            rChanged = true
          end
        end
      end

      return rChanged
    end

    # Create a Shortcut if it does not exit, or merge Tags if already existing.
    #
    # Parameters:
    # * *iTypeName* (_String_): The type name
    # * *iContent* (_Object_): The content
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # * *iTags* (<em>map<Tag,nil></em>): The set of Tags
    # Return:
    # * _Shortcut_: The newly created Shortcut
    def createShortcut(iTypeName, iContent, iMetadata, iTags)
      # First find if we don't violate unicity constraints
      rShortcut = nil

      ensureUndoableOperation("Create Shortcut #{iMetadata['title']}") do
        rShortcut, lAction = checkShortcutUnicity(iTypeName, iContent, iMetadata, iTags)
        if ((rShortcut == nil) or
            (lAction == ID_KEEP))
          # Create it
          lType = @TypesPlugins[iTypeName]
          if (lType == nil)
            puts "!!! Unknown type named #{iTypeName}. Cannot create Shortcut #{iMetadata['title']}."
          else
            rShortcut = atomicOperation(Controller::UAO_CreateShortcut.new(self, lType, iContent, iMetadata, iTags))
            setCurrentFileModified
          end
        end
      end

      return rShortcut
    end

    # Delete a given Shortcut
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): The Shortcut to delete
    def deleteShortcut(iShortcut)
      ensureUndoableOperation("Delete Shortcut #{iShortcut.Metadata['title']}") do
        atomicOperation(Controller::UAO_DeleteShortcut.new(self, iShortcut))
        setCurrentFileModified
      end
    end

    # Modify the Shortcut based on new data.
    # Only this method should be used by commands to update a Shortcut's info.
    #
    # Parameters:
    # * *ioSC* (_Shortcut_): The Shortcut to modify
    # * *iNewContent* (_Object_): The new Content
    # * *iNewMetadata* (<em>map<String,Object></em>): The new Metadata
    # * *iNewTags* (<em>map<Tag,nil></em>): The new Tags
    # Return:
    # * _Boolean_: Did the data effectively changed ? (It will also be true if the update resulted in a delete of the Shortcut)
    def updateShortcut(ioSC, iNewContent, iNewMetadata, iNewTags)
      rChanged = false

      if ((ioSC.Content != iNewContent) or
          (ioSC.Metadata != iNewMetadata) or
          (ioSC.Tags != iNewTags))
        # First find if we don't violate unicity constraints
        ensureUndoableOperation("Update Shortcut #{ioSC.Metadata['title']}") do
          lDoublon, lAction = checkShortcutUnicity(ioSC.Type.pluginName, iNewContent, iNewMetadata, iNewTags, ioSC)
          if ((lDoublon == nil) or
              (lAction == ID_KEEP))
            atomicOperation(Controller::UAO_UpdateShortcut.new(self, ioSC, iNewContent, iNewMetadata, iNewTags))
            setCurrentFileModified
            rChanged = true
          elsif (lAction == ID_MERGE)
            # We have to delete the Shortcut we were updating, as it has been merged in lDoublon
            deleteShortcut(ioSC)
            rChanged = true
          end
        end
      end

      return rChanged
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
      if (!@CurrentOpenedFileModified)
        ensureUndoableOperation('Flag current project as modified') do
          atomicOperation(Controller::UAO_SetFileModified.new(self))
        end
      end
    end

    # Method that check current work is saved, asks the user if not, and scratches the whole data.
    # In merge context, it does nothing.
    #
    # Parameters:
    # * *iParentWindow* (<em>Wx::Window</em>): The parent window
    # Return:
    # * _Boolean_: Has current work been saved (true also if user decides to continue without saving deliberately) ?
    def checkSavedWorkAndScratch(iParentWindow)
      rSaved = true

      # First check
      if (!@Merging)
        rSaved = checkSavedWork(iParentWindow)
        # Then scratch
        if (rSaved)
          # Scratch everything
          # Perform it on a clone of the list as it will be modified
          @ShortcutsList.clone.each do |iSC|
            deleteShortcut(iSC)
          end
          @RootTag.Children.clone.each do |iChildTag|
            deleteTag(iChildTag)
          end
        end
      end

      return rSaved
    end

    # Method that check current work is saved, asks the user if not.
    #
    # Parameters:
    # * *iParentWindow* (<em>Wx::Window</em>): The parent window
    # Return:
    # * _Boolean_: Has current work been saved (true also if user decides to continue without saving deliberately) ?
    def checkSavedWork(iParentWindow)
      rSaved = true

      # First check if we haven't saved current work
      if (@CurrentOpenedFileModified)
        showModal(Wx::MessageDialog, iParentWindow,
          "Current Shortcuts are not saved.\nAre you sure you want to discard current Shortcuts to load new ones ?\nYou will still be able to undo the operation in case of mistake.",
          :caption => 'Confirm discard',
          :style => Wx::YES_NO|Wx::NO_DEFAULT|Wx::ICON_EXCLAMATION
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_NO
            rSaved = false
          end
        end
      end

      return rSaved
    end

  end

end
