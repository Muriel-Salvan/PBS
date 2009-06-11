#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every method used by the Undoable Atomic Operations to broadcast notifications of data model changes.
  module Notifiers

    # Called when the clipboard's content has changed.
    # This method will the use the @Clipboard_* variables to adapt the Paste command aspect and the local Cut/Copy variables eventually.
    def notifyClipboardContentChanged
      updateCommand(Wx::ID_PASTE) do |ioCommand|
        if (@Clipboard_CopyMode == nil)
          # The clipboard has nothing interesting for us
          # Deactivate the Paste command
          ioCommand[:enabled] = false
          ioCommand[:title] = 'Paste'
          # Cancel eventual Copy/Cut pending commands
          notifyCancelCopy
          # Notify everybody
          notifyRegisteredGUIs(:onClipboardContentChanged)
        elsif (@Clipboard_CopyMode == Wx::ID_DELETE)
          # Check that this message is adressed to us for real (if many instances of PBS are running, it is possible that some other instance was cutting things)
          if (@CopiedID == @Clipboard_CopyID)
            # Here we have to take some action:
            # Delete the objects marked as being 'Cut', as we got the acknowledge of pasting it somewhere.
            if (@CopiedMode == Wx::ID_CUT)
              if (!@Clipboard_AlreadyProcessingDelete)
                # Ensure that the loop will not come here again for this item.
                @Clipboard_AlreadyProcessingDelete = true
                cmdDelete({
                    :parentWindow => nil,
                    :selection => @CopiedSelection,
                    :deleteTaggedShortcuts => false,
                    :deleteOrphanShortcuts => false
                  })
                # Then empty the clipboard.
                Wx::Clipboard.open do |ioClipboard|
                  ioClipboard.clear
                end
                # Cancel the Cut pending commands.
                notifyCutPerformed
                notifyRegisteredGUIs(:onClipboardContentChanged)
                @Clipboard_AlreadyProcessingDelete = false
              end
            else
              puts '!!! We have been notified of a clipboard Cut acknowledgement, but no item was marked as to be Cut. Bug ?'
            end
          end
          # Deactivate the Paste command
          ioCommand[:enabled] = false
          ioCommand[:title] = 'Paste'
        else
          lCopyName = nil
          case @Clipboard_CopyMode
          when Wx::ID_CUT
            lCopyName = 'Move'
          when Wx::ID_COPY
            lCopyName = 'Copy'
          else
            puts "!!! Unsupported copy type from the clipboard: #{@Clipboard_CopyMode}. Bug ?"
          end
          if (@Clipboard_CopyID != @CopiedID)
            # Here, we have another application of PBS that has put data in the clipboard. It is not us anymore.
            notifyCancelCopy
          end
          if (lCopyName != nil)
            # Activate the Paste command with a cool title
            ioCommand[:enabled] = true
            ioCommand[:title] = "Paste #{@Clipboard_SerializedSelection.getDescription} (#{lCopyName})"
          else
            # Deactivate the Paste command, and explain why
            ioCommand[:enabled] = false
            ioCommand[:title] = "Paste (invalid type #{@Clipboard_CopyMode}) - Bug ?"
          end
          notifyRegisteredGUIs(:onClipboardContentChanged)
        end
      end
    end

    # Notify the GUI that we are initializing the GUI.
    # This step performs just after having created and registered all windows.
    def notifyInit
      # Initialize appearance of many components
      notifyUndoUpdate
      notifyRedoUpdate
      notifyClipboardContentChanged
      notifyCurrentOpenedFileUpdate
      @Commands.each do |iCommandID, iCommandParams|
        updateImpactedAppearance(iCommandID)
      end
      # Notify everybody that we are initializing
      notifyRegisteredGUIs(:onInit)
      # Create the Timer monitoring the clipboard
      # This Timer populates the following variables with the clipboard content in real-time:
      # * @Clipboard_CopyMode
      # * @Clipboard_CopyID
      # * @Clipboard_SerializedSelection
      # Note that we are already in the process of a delete event from the clipboard.
      @Clipboard_AlreadyProcessingDelete = false
      Wx::Timer.every(500) do
        # Check if the clipboard has some data we can paste
        Wx::Clipboard.open do |iClipboard|
          if (iClipboard.supported?(Tools::DataObjectSelection.getDataFormat))
            # OK, this is data we understand.
            # Get some details to display what we can paste
            lClipboardData = Tools::DataObjectSelection.new
            iClipboard.get_data(lClipboardData)
            lCopyMode, lCopyID, lSerializedSelection = lClipboardData.getData
            # Do not change the state if the content has not changed
            if ((lCopyMode != @Clipboard_CopyMode) or
                (lCopyID != @Clipboard_CopyID))
              # Clipboard's content has changed.
              @Clipboard_CopyMode = lCopyMode
              @Clipboard_CopyID = lCopyID
              @Clipboard_SerializedSelection = lSerializedSelection
              notifyClipboardContentChanged
            # Else, nothing to do, clipboard's state has not changed.
            end
          elsif (@Clipboard_CopyMode != nil)
            # Clipboard has nothing interesting anymore.
            @Clipboard_CopyMode = nil
            @Clipboard_CopyID = nil
            @Clipboard_SerializedSelection = nil
            notifyClipboardContentChanged
          # Else, nothing to do, clipboard's state has not changed.
          end
        end
      end
    end

    # Notify the GUI that we are quitting
    def notifyExit
      notifyRegisteredGUIs(:onExit)
    end

    # Notify the GUI that options have changed
    #
    # Parameters:
    # * *iOldOptions* (<em>map<Symbol,Object></em>): Old options
    def notifyOptionsChanged(iOldOptions)
      notifyRegisteredGUIs(:onOptionsChanged, iOldOptions)
    end

    # Notify the GUI that data on the current opened file has been modified
    def notifyCurrentOpenedFileUpdate
      updateCommand(Wx::ID_SAVE) do |ioCommand|
        if (@CurrentOpenedFileName == nil)
          ioCommand[:title] = 'Save'
          ioCommand[:enabled] = false
        else
          ioCommand[:title] = "Save #{File.basename(@CurrentOpenedFileName)}"
          ioCommand[:enabled] = @CurrentOpenedFileModified
        end
      end
      notifyRegisteredGUIs(:onCurrentOpenedFileUpdate)
    end

    # Notify the GUI that the Undo stack has been modified
    def notifyUndoUpdate
      updateCommand(Wx::ID_UNDO) do |ioCommand|
        if (@UndoStack.empty?)
          ioCommand[:title] = 'Undo'
          ioCommand[:enabled] = false
        else
          lLastOperationTitle = @UndoStack[-1].Title
          ioCommand[:title] = "Undo #{lLastOperationTitle}"
          ioCommand[:enabled] = true
        end
      end
    end

    # Notify the GUI that the Redo stack has been modified
    def notifyRedoUpdate
      updateCommand(Wx::ID_REDO) do |ioCommand|
        if (@RedoStack.empty?)
          ioCommand[:title] = 'Redo'
          ioCommand[:enabled] = false
        else
          lLastOperationTitle = @RedoStack[-1].Title
          ioCommand[:title] = "Redo #{lLastOperationTitle}"
          ioCommand[:enabled] = true
        end
      end
    end

    # Notify that a given Tag's children list has changed
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The Tag whose children list has changed
    # * *iOldChildrenList* (<em>list<Tag></em>): The old children list
    def notifyTagChildrenUpdate(iParentTag, iOldChildrenList)
      notifyRegisteredGUIs(:onTagChildrenUpdate, iParentTag, iOldChildrenList)
    end

    # Mark a Tag whose data has been invalidated
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag whose data was invalidated
    # * *iOldName* (_String_): The previous name
    # * *iOldIcon* (<em>Wx::Bitmap</em>): The previous icon (can be nil)
    def notifyTagDataUpdate(iTag, iOldName, iOldIcon)
      notifyRegisteredGUIs(:onTagDataUpdate, iTag, iOldName, iOldIcon)
    end

    # Mark a Shortcut whose data (content or metadata) has been invalidated
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut whose data was invalidated
    # * *iOldContent* (_Object_): The previous content, or nil if it was not modified
    # * *iOldMetadata* (_Object_): The previous metadata, or nil if it was not modified
    def notifyShortcutDataUpdate(iSC, iOldContent, iOldMetadata)
      notifyRegisteredGUIs(:onShortcutDataUpdate, iSC, iOldContent, iOldMetadata)
    end

    # Notify that a Shortcut has just been added
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The new Shortcut
    def notifyShortcutCreate(iSC)
      notifyRegisteredGUIs(:onShortcutCreate, iSC)
    end

    # Notify that a Shortcut has just been deleted
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The deleted Shortcut
    def notifyShortcutDelete(iSC)
      notifyRegisteredGUIs(:onShortcutDelete, iSC)
    end

    # Mark a Shortcut whose tags (content or metadata) have been invalidated
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut whose Tags were invalidated
    # * *iOldTags* (<em>map<Tag,nil></em>): The old Tags set
    def notifyShortcutTagsUpdate(iSC, iOldTags)
      notifyRegisteredGUIs(:onShortcutTagsUpdate, iSC, iOldTags)
    end

    # Notify the GUI that what has enventually been copied/cut is not anymore available
    def notifyCancelCopy
      if (@CopiedSelection != nil)
        notifyRegisteredGUIs(:onCancelCopy, @CopiedSelection)
        @CopiedSelection = nil
        @CopiedMode = nil
        @CopiedID = nil
      end
    end

    # Notify the GUI that an object has just been copied
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    # * *iCopyID* (_Integer_): Unique ID identifying this Copy operation
    def notifyObjectsCopied(iSelection, iCopyID)
      # First notify to uncopy the previous ones
      notifyCancelCopy
      @CopiedSelection = iSelection
      @CopiedMode = Wx::ID_COPY
      @CopiedID = iCopyID
      notifyRegisteredGUIs(:onObjectsCopied, @CopiedSelection)
    end

    # Notify the GUI that an object has just been cut
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    # * *iCopyID* (_Integer_): Unique ID identifying this Copy operation
    def notifyObjectsCut(iSelection, iCopyID)
      # First notify to uncopy the previous
      notifyCancelCopy
      @CopiedSelection = iSelection
      @CopiedMode = Wx::ID_CUT
      @CopiedID = iCopyID
      notifyRegisteredGUIs(:onObjectsCut, @CopiedSelection)
    end

    # Notify the GUI that the Cut has effectively been performed
    def notifyCutPerformed
      if (@CopiedSelection != nil)
        notifyRegisteredGUIs(:onCutPerformed, @CopiedSelection)
        @CopiedSelection = nil
        @CopiedMode = nil
        @CopiedID = nil
      end
    end

    # Notify the GUI that a selection is being moved using Drag'n'Drop
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def notifyObjectsDragMove(iSelection)
      @DragSelection = iSelection
      @DragMode = Wx::DRAG_MOVE
      notifyRegisteredGUIs(:onObjectsDragMove, @DragSelection)
    end

    # Notify the GUI that a selection is being copied using Drag'n'Drop
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def notifyObjectsDragCopy(iSelection)
      @DragSelection = iSelection
      @DragMode = Wx::DRAG_COPY
      notifyRegisteredGUIs(:onObjectsDragCopy, @DragSelection)
    end

    # Notify the GUI that a selection is being invalidated using Drag'n'Drop
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def notifyObjectsDragNone(iSelection)
      @DragSelection = iSelection
      @DragMode = Wx::DRAG_NONE
      notifyRegisteredGUIs(:onObjectsDragNone, @DragSelection)
    end

    # Notify the GUI that a Drag'n'Drop operation has ended
    #
    # Parameters:
    # * *iDragResult* (_Integer_): The result of the Drag'n'Drop operation
    def notifyObjectsDragEnd(iDragResult)
      notifyRegisteredGUIs(:onObjectsDragEnd, @DragSelection, iDragResult)
      @DragSelection = nil
      @DragMode = nil
    end

  end

end
