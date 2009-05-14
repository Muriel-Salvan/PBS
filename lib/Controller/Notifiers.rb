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
      if (@UndoStack.empty?)
        @Commands[Wx::ID_UNDO][:title] = 'Undo'
        @Commands[Wx::ID_UNDO][:enabled] = false
      else
        lLastOperationTitle = @UndoStack[-1].Title
        @Commands[Wx::ID_UNDO][:title] = "Undo #{lLastOperationTitle}"
        @Commands[Wx::ID_UNDO][:enabled] = true
      end
      updateImpactedAppearance(Wx::ID_UNDO)
    end

    # Notify the GUI that the Redo stack has been modified
    def notifyRedoUpdate
      if (@RedoStack.empty?)
        @Commands[Wx::ID_REDO][:title] = 'Redo'
        @Commands[Wx::ID_REDO][:enabled] = false
      else
        lLastOperationTitle = @RedoStack[-1].Title
        @Commands[Wx::ID_REDO][:title] = "Redo #{lLastOperationTitle}"
        @Commands[Wx::ID_REDO][:enabled] = true
      end
      updateImpactedAppearance(Wx::ID_REDO)
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

  end

end
