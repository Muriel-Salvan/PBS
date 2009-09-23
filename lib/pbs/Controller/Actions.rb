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
      # This method can be called recursively. Be prepared for it.
      if (@CurrentUndoableOperation == nil)
        logInfo "= #{iOperationTitle} ..."
        # Create the corresponding ProgressBar
        setupTextProgress(Wx::get_app.get_top_window, iOperationTitle,
          :Cancellable => true,
          :Title => iOperationTitle,
          :Icon => getGraphic('IconProcess32.png')
        ) do |ioProgressDlg|
          @CurrentProgressDlg = ioProgressDlg
          # Create the current Undo context: this is the object that will be saved in the Undo/Redo stacks
          @CurrentUndoableOperation = Controller::UndoableOperation.new(iOperationTitle)
          # Reset the transaction context
          @CurrentTransactionToBeCancelled = false
          @CurrentOperationTagsConflicts = nil
          @CurrentOperationShortcutsConflicts = nil
          # Don't display errors live, but store them temporarily instead
          lCurrentTransactionErrors = []
          setLogErrorsStack(lCurrentTransactionErrors)
          begin
            # Call the command code
            yield
          rescue Exception
            logExc $!, "Exception encountered during execution of \"#{iOperationTitle}\""
          end
          setLogErrorsStack(nil)
          # Check possible errors
          if (!lCurrentTransactionErrors.empty?)
            lErrorsText = nil
            if (lCurrentTransactionErrors.size > MAX_ERRORS_PER_DIALOG)
              lErrorsText = "Showing only #{MAX_ERRORS_PER_DIALOG} first errors:\n* #{lCurrentTransactionErrors[0..MAX_ERRORS_PER_DIALOG-1].join("\n* ")}"
            else
              lErrorsText = "* #{lCurrentTransactionErrors.join("\n* ")}"
            end
            # Display errors
            showModal(Wx::MessageDialog, nil,
              lErrorsText,
              "#{lCurrentTransactionErrors.size} error(s) during #{iOperationTitle}",
              :style => Wx::OK|Wx::ICON_HAND
            ) do |iModalResult, iDialog|
              # Nothing to do
            end
          end
          # Check that the client code effectively modified something before creating an Undo
          if (!@CurrentUndoableOperation.AtomicOperations.empty?)
            # If we want to cancel the whole operation, do it now
            if ((@CurrentTransactionToBeCancelled) or
                (@CurrentProgressDlg.Cancelled))
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
          @CurrentProgressDlg = nil
        end
        logInfo "= ... #{iOperationTitle}"
      else
        # No special transaction
        yield
      end
    end

    # Add a given range to the current progression.
    # This sets the progression to determined if it was not already.
    #
    # Parameters:
    # * *iRange* (_Integer_): Range to add to the progression
    def addProgressionRange(iRange)
      @CurrentProgressDlg.incRange(iRange)
    end

    # Increment the current progression.
    #
    # Parameters:
    # * *iIncrement* (_Integer_): Increment to apply [optional = 1]
    def incProgression(iIncrement = 1)
      @CurrentProgressDlg.incValue(iIncrement)
    end

    # Set the progression text
    #
    # Parameters:
    # * *iText* (_String_): Text
    def setProgressionText(iText)
      @CurrentProgressDlg.setText(iText)
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
        rTag, lAction, lNewTagName, lNewIcon = checkTagUnicity(iParentTag, iTagName, iIcon)
        if ((rTag == nil) or
            (lAction == ID_KEEP))
          # OK, create it
          rTag = atomicOperation(Controller::UAO_CreateTag.new(self, iParentTag, lNewTagName, lNewIcon))
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
          lDoublon, lAction, lNewTagName, lNewIcon = checkTagUnicity(ioTag.Parent, iNewName, iNewIcon, ioTag)
          if ((lDoublon == nil) or
              (lAction == ID_KEEP))
            atomicOperation(Controller::UAO_UpdateTag.new(self, ioTag, lNewTagName, lNewIcon, iNewChildren))
            setCurrentFileModified
            rChanged = true
          elsif ((lAction == ID_MERGE_EXISTING) or
                 (lAction == ID_MERGE_CONFLICTING))
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

      accessTypesPlugin(iTypeName) do |iTypePlugin|
        ensureUndoableOperation("Create Shortcut #{iMetadata['title']}") do
          rShortcut, lAction, lNewContent, lNewMetadata = checkShortcutUnicity(iTypePlugin, iContent, iMetadata, iTags)
          if ((rShortcut == nil) or
              (lAction == ID_KEEP))
            # Create it
            rShortcut = atomicOperation(Controller::UAO_CreateShortcut.new(self, iTypePlugin, lNewContent, lNewMetadata, iTags))
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
          lDoublon, lAction, lNewContent, lNewMetadata = checkShortcutUnicity(ioSC.Type, iNewContent, iNewMetadata, iNewTags, ioSC)
          if ((lDoublon == nil) or
              (lAction == ID_KEEP))
            atomicOperation(Controller::UAO_UpdateShortcut.new(self, ioSC, lNewContent, lNewMetadata, iNewTags))
            setCurrentFileModified
            rChanged = true
          elsif ((lAction == ID_MERGE_EXISTING) or
                 (lAction == ID_MERGE_CONFLICTING))
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
          "Current Shortcuts are not saved.\nAre you sure you want to discard current Shortcuts ?",
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
    
    # Execute a given command
    #
    # Parameters:
    # * *iCommandID* (_Integer_): The command ID
    # * *iParams* (<em>map<Symbol,Object></em>): The parameters to give the command (nil if no parameters) [optional = nil]
    def executeCommand(iCommandID, iParams = nil)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        logBug "Command #{iCommandID} is not registered. Can't execute it. Please check command plugins."
      else
        if (lCommand[:Plugin] == nil)
          # Get the plugin name to access
          begin
            accessPlugin('Command', lCommand[:PluginName]) do |iPlugin|
              lCommand[:Plugin] = iPlugin
            end
          rescue Exception
            # Nothing to do, we'll display the error message later.
          end
          if (lCommand[:Plugin] == nil)
            showModal(Wx::MessageDialog, nil,
              "This command (#{iCommandID}) has not yet been implemented. Sorry.",
              :caption => 'Not yet implemented',
              :style => Wx::OK|Wx::ICON_EXCLAMATION
            ) do |iModalResult, iDialog|
              # Nothing to do
            end
          end
        end
        if (lCommand[:Plugin] != nil)
          if (iParams == nil)
            # Check that the command did not need any parameters first
            if ((lCommand[:Parameters] != nil) and
                (!lCommand[:Parameters].empty?))
              logBug "Command #{iCommandID} should be called with parameters, but the GUI did not pass any. Please correct GUI code or command plugin parameters."
            end
            # Call the command method without parameters
            begin
              lCommand[:Plugin].execute(self)
            rescue
              logExc $!, "Command \"#{lCommand[:Title]}\" (called without parameters) threw an exception"
            end
          else
            if (lCommand[:Parameters] != nil)
              # Check that all parameters have been set
              lCommand[:Parameters].each do |iParameterSymbol|
                if (!iParams.has_key?(iParameterSymbol))
                  logBug "Missing parameter #{iParameterSymbol.to_s} set by the GUI for command #{iCommandID}. Please correct GUI code or command plugin parameters."
                end
              end
            end
            # Call the command method with the parameters given by the validator
            begin
              lCommand[:Plugin].execute(self, iParams)
            rescue
              logExc $!, "Command \"#{lCommand[:Title]}\" (called with parameters: #{iParams.inspect}) threw an exception"
            end
          end
        end
      end
    end

  end

end
