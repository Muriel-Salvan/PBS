#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every method used by the Undoable Atomic Operations to broadcast notifications of data model changes.
  module Notifiers

    # Notify the GUI that we are initializing the GUI.
    # This step performs just after having created and registered all windows.
    def notifyInit
      # Initialize appearance of many components
      notifyUndoUpdate
      notifyRedoUpdate
      @Commands.each do |iCommandID, iCommandParams|
        updateImpactedAppearance(iCommandID)
      end
      notifyRegisteredGUIs(:onInit)
      # Create the Timer monitoring the clipboard
      Wx::Timer.every(500) do
        # Check if the clipboard has some data we can paste
        Wx::Clipboard.open do |iClipboard|
          updateCommand(Wx::ID_PASTE) do |ioCommand|
            if iClipboard.supported?(Tools::DataObjectTag.getDataFormat)
              # OK, this is data we understand.
              # Get some details to display what we can paste
              lClipboardData = Tools::DataObjectTag.new
              iClipboard.get_data(lClipboardData)
              lDataID, lDataContent = Marshal.load(lClipboardData.Data)
              lName = nil
              case lDataID
              when ID_TAG
                lName = "Tag #{Tag.getSerializedTagName(lDataContent)}"
              when ID_SHORTCUT
                lName = "Shortcut #{Shortcut.getSerializedShortcutName(lDataContent)}"
              end
              if (lName != nil)
                # Activate the Paste command with a cool title
                ioCommand[:enabled] = true
                ioCommand[:title] = "Paste #{lName}"
              else
                # Deactivate the Paste command, and explain why
                ioCommand[:enabled] = false
                ioCommand[:title] = "Paste (invalid id #{lDataID}) - Bug ?"
              end
            else
              # Deactivate the Paste command
              ioCommand[:enabled] = false
              ioCommand[:title] = 'Paste'
              # Cancel eventual Copy/Cut pending commands
              notifyCancelCopy
            end
          end
        end
      end
    end

    # Notify the GUI that we are quitting
    def notifyFinal
      notifyRegisteredGUIs(:onFinal)
    end

    # Notify the GUI that data on the current opened file has been modified
    def notifyCurrentOpenedFileUpdate
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

    # Mark a Shortcut whose data (content or metadata) has been invalidated
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut whose data was invalidated
    # * *iOldSCID* (_Integer_): The Shortcut ID before data modification
    # * *iOldContent* (_Object_): The previous content, or nil if it was not modified
    # * *iOldMetadata* (_Object_): The previous metadata, or nil if it was not modified
    def notifyShortcutDataUpdate(iSC, iOldSCID, iOldContent, iOldMetadata)
      notifyRegisteredGUIs(:onShortcutDataUpdate, iSC, iOldSCID, iOldContent, iOldMetadata)
    end

    # Notify that a Shortcut has just been added
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The new Shortcut
    def notifyShortcutAdd(iSC)
      notifyRegisteredGUIs(:onShortcutAdd, iSC)
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

    # Notify the GUI that complete Shortcuts/Tags data have been changed
    def notifyReplaceAll
      notifyRegisteredGUIs(:onReplaceAll)
    end

    # Notify the GUI that what has enventually been copied/cut is not anymore available
    def notifyCancelCopy
      if (@CopiedObjectID != nil)
        notifyRegisteredGUIs(:onCancelCopy, @CopiedObjectID, @CopiedObject)
        @CopiedObjectID = nil
        @CopiedObject = nil
        @CopiedMode = nil
      end
    end

    # Notify the GUI that an object has just been copied
    #
    # Parameters:
    # * *iObjectID* (_Integer_): Object ID
    # * *iObject* (_Object_): The object
    def notifyObjectCopied(iObjectID, iObject)
      # First notify to uncopy the previous
      notifyCancelCopy
      @CopiedObjectID = iObjectID
      @CopiedObject = iObject
      @CopiedMode = Wx::ID_COPY
      notifyRegisteredGUIs(:onObjectCopy, @CopiedObjectID, @CopiedObject)
    end

    # Notify the GUI that an object has just been cut
    #
    # Parameters:
    # * *iObjectID* (_Integer_): Object ID
    # * *iObject* (_Object_): The object
    def notifyObjectCut(iObjectID, iObject)
      # First notify to uncopy the previous
      notifyCancelCopy
      @CopiedObjectID = iObjectID
      @CopiedObject = iObject
      @CopiedMode = Wx::ID_CUT
      notifyRegisteredGUIs(:onObjectCut, @CopiedObjectID, @CopiedObject)
    end

  end

end
