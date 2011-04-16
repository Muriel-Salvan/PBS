#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every class defining Undoable Atomic Operations, that is simple operations on the data that are protected with do/undo methods.
  # These classes are used with a set of methods also defined in this module.
  # Those methods/classes should be exclusively used by Actions methods, themselves invoked by the Commands.
  module UndoableAtomicOperations

    # Base class for every undoable atomic operation.
    # Here are some considerations to ENSURE when coding Undo/Redo atomic operations:
    # * Objects created/saved HAVE to be persistent. That is to say a created Shortcut undone and redone has to be the same object again, at the same memory adress. It has to use .new just once.
    # This way the Undo/Redo chain will always change the same object little by little, and we will be certain to have a correct behaviour without cloning data.
    # To be more convinced, check this use case (description with examples of no object persistence to illustrate the problem):
    # 01. Do Create New Shortcut: SC1.title = 'A' (Save 01.NewSC = SC1)
    # 02. Do Modify SC1.title = 'B' (Save 02.OldTitle = SC1.title and 02.NewTitle = 'B')
    # 03. Do Modify SC1.title = 'C' (Save 03.OldTitle = SC1.title and 03.NewTitle = 'C')
    # 04. Do Delete SC1 (Save 04.OldSC = SC1)
    # 05. Undo (Recreate SC1: a different object in memory, with title='C')
    # 06. Undo (Modify SC1.title = 03.OldTitle) !!! Here, if Operation 03. did not clone SC1.Oldtitle during Save, 03.OldTitle == 'C', which is incorrect
    # 07. Undo (Modify SC1.title = 02.OldTitle) !!! Here, if Operation 02. did not clone SC1.OldTitle during Save, 02.OldTitle == 'C', which is incorrect
    # 08. Undo (Delete SC1)
    # 09. Redo (Recreate SC1: a different object in memory, with title='A')
    # 10. Redo (Modify SC1.title = 02.NewTitle) !!! Here, if Operation 02. did not clone 02.NewTitle during Use, Operation 03. would have modified 02.NewTitle to 'C', and never undone it as due to Operation 04., undoing Operation 03. modified a different object in memory.
    # 11. Redo (Modify SC1.title = 03.NewTitle) !!! Here, if Operation 03. did not clone 03.NewTitle during Save, Operation 02. would have modified it to 'B' during the Undo of Operation 02, which is incorrect. !!! Also here, if Operation 03. did not clone 03.OldTitle during Use, Undoing operation 02. would have modified it to 'B', and not corrected before redoing Operation 01. has created a different object in memory.
    # * No references to Tags or Shortcuts from the main data (@Controller.ShortcutsList or @Controller.RootTag) should be saved in an object. Always use IDs. This is because the references can then become obsolete later when replacing the data. There is no guarantee at all on the persistent of Shortcuts/Tags references.
    class UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller giving access to the model
      def initialize(iController)
        @Controller = iController
      end

    end

    # Add a new atomic operation in the current undoable transaction, and perform its operation.
    #
    # Parameters:
    # * *iUndoableAtomicOperation* (_UndoableAtomicOperation_): The atomic operation
    # Return:
    # * _Object_: The return of the doOperation
    def atomicOperation(iUndoableAtomicOperation)
      @CurrentUndoableOperation.AtomicOperations << iUndoableAtomicOperation
      # Pulse the progression if it is still undetermined.
      # If the progression is determined, we consider that the process already calls incProgression, which gives hand to the user already.
      if (!@CurrentProgressDlg.Determined)
        @CurrentProgressDlg.pulse
      end
      # Perform it right now
      iUndoableAtomicOperation.doOperation
    end

    # ### Following are Undoable Atomic Operations useable with atomicOperation method.
    # ### Those classes are the only ones allowed to manipulate the datamodel (that is data linked to @Controller.ShortcutsList or @Controller.RootTag).
    # ### To ensure that code does not manipulate data outside those classes, every single data manipulation method is prefixed with _UNDO_.

    # Class that creates a new Tag as a child of an existing one
    class UAO_CreateTag < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *ioParentTag* (_Tag_): The Tag that will receive the new one
      # * *iName* (_String_): The Tag name
      # * *iIcon* (<em>Wx::Bitmap</em>): The Tag icon
      def initialize(iController, ioParentTag, iName, iIcon)
        super(iController)

        @ParentTag = ioParentTag
        @NewTag = Tag.new(iName, iIcon)
      end

      # Perform the operation
      #
      # Return:
      # * _Tag_: The newly created Tag
      def doOperation
        logDebug "UAO_CreateTag #{@NewTag.Name}"
        lOldChildrenList = @ParentTag.Children.clone
        @ParentTag._UNDO_addChild(@NewTag)
        @Controller.notifyTagChildrenUpdate(@ParentTag, lOldChildrenList)

        return @NewTag
      end

      # Undo the operation
      def undoOperation
        logDebug "UNDO - UAO_CreateTag #{@NewTag.Name}"
        lOldChildrenList = @ParentTag.Children.clone
        @ParentTag._UNDO_deleteChild(@NewTag)
        @Controller.notifyTagChildrenUpdate(@ParentTag, lOldChildrenList)
      end

    end

    # Class that deletes a Tag
    class UAO_DeleteTag < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iTag* (_Tag_): The Tag to delete
      def initialize(iController, iTag)
        super(iController)

        @Tag = iTag
        @ParentTag = iTag.Parent
      end

      # Perform the operation
      def doOperation
        logDebug "UAO_DeleteTag #{@Tag.Name}"
        lOldChildrenList = @ParentTag.Children.clone
        @ParentTag._UNDO_deleteChild(@Tag)
        @Controller.notifyTagChildrenUpdate(@ParentTag, lOldChildrenList)
      end

      # Undo the operation
      def undoOperation
        logDebug "UNDO - UAO_DeleteTag #{@Tag.Name}"
        lOldChildrenList = @ParentTag.Children.clone
        @ParentTag._UNDO_addChild(@Tag)
        @Controller.notifyTagChildrenUpdate(@ParentTag, lOldChildrenList)
      end

    end

    # Class that modifies a Tag
    class UAO_UpdateTag < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iTag* (_Tag_): The Tag being modified
      # * *iNewName* (_String_): The new name
      # * *iNewIcon* (<em>Wx::Bitmap</em>): The new icon (can be nil)
      # * *iNewSubTags* (<em>list<Tag></em>): The new sub-Tags
      def initialize(iController, iTag, iNewName, iNewIcon, iNewSubTags)
        super(iController)

        @Tag = iTag
        if (iTag.Name != iNewName)
          @OldName = iTag.Name
          @NewName = iNewName
        else
          @OldName = nil
          @NewName = nil
        end
        if (iTag.Icon != iNewIcon)
          if (iTag.Icon == nil)
            @OldIcon = nil
          else
            @OldIcon = iTag.Icon
          end
          if (iNewIcon == nil)
            @NewIcon = nil
          else
            @NewIcon = iNewIcon
          end
        else
          @OldIcon = nil
          @NewIcon = nil
        end
        if (iTag.Children != iNewSubTags)
          # Here we clone as the assignment is not made by replacing the Tag.Children property, but by changing the current one instead.
          @OldSubTags = iTag.Children.clone
          @NewSubTags = iNewSubTags
        else
          @OldSubTags = nil
          @NewSubTags = nil
        end
      end

      # Perform the operation
      def doOperation
        logDebug "UAO_UpdateTag #{@OldName}"
        if ((@NewName != nil) or
            (@NewIcon != nil) or
            (@OldIcon != nil))
          if (@NewName != nil)
            @Tag._UNDO_setName(@NewName)
          end
          if ((@NewIcon != nil) or
              (@OldIcon != nil))
            if (@NewIcon == nil)
              @Tag._UNDO_setIcon(nil)
            else
              @Tag._UNDO_setIcon(@NewIcon)
            end
          end
          @Controller.notifyTagDataUpdate(@Tag, @OldName, @OldIcon)
        end
        if (@NewSubTags != nil)
          lOldSubTags = @Tag.Children.clone
          @Tag._UNDO_setSubTags(@NewSubTags).each do |iParentTag, iOldSubTags|
            @Controller.notifyTagChildrenUpdate(iParentTag, iOldSubTags)
          end
          @Controller.notifyTagChildrenUpdate(@Tag, lOldSubTags)
        end
      end

      # Undo the operation
      def undoOperation
        # Retrieve the Shortcut
        logDebug "UNDO - UAO_UpdateTag #{@NewName}"
        if ((@OldName != nil) or
            (@OldIcon != nil) or
            (@NewIcon != nil))
          if (@OldName != nil)
            @Tag._UNDO_setName(@OldName)
          end
          if ((@OldIcon != nil) or
              (@NewIcon != nil))
            if (@OldIcon == nil)
              @Tag._UNDO_setIcon(nil)
            else
              @Tag._UNDO_setIcon(@OldIcon)
            end
          end
          @Controller.notifyTagDataUpdate(@Tag, @NewName, @NewIcon)
        end
        if (@OldSubTags != nil)
          lOldSubTags = @Tag.Children.clone
          @Tag._UNDO_setSubTags(@OldSubTags).each do |iParentTag, iOldSubTags|
            @Controller.notifyTagChildrenUpdate(iParentTag, iOldSubTags)
          end
          @Controller.notifyTagChildrenUpdate(@Tag, lOldSubTags)
        end
      end

    end

    # Class that creates a new Shortcut
    class UAO_CreateShortcut < UndoableAtomicOperation
      
      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iType* (_ShortcutType_): The Shortcut type to create
      # * *iContent* (_Object_): The content
      # * *iMetadata* (<em>map<String,Object></em>): The metadata
      # * *iTags* (<em>map<Tag,nil></em>): The Tags set
      def initialize(iController, iType, iContent, iMetadata, iTags)
        super(iController)

        @NewShortcut = Shortcut.new(iType, iContent, iMetadata, iTags)
      end

      # Perform the operation
      #
      # Return:
      # * _Shortcut_: The newly created Shortcut
      def doOperation
        logDebug "UAO_CreateShortcut #{@NewShortcut.Metadata['title']}"
        @Controller._UNDO_addShortcut(@NewShortcut)
        @Controller.notifyShortcutCreate(@NewShortcut)

        return @NewShortcut
      end

      # Undo the operation
      def undoOperation
        logDebug "UNDO - UAO_CreateShortcut #{@NewShortcut.Metadata['title']}"
        @Controller._UNDO_deleteShortcut(@NewShortcut)
        @Controller.notifyShortcutDelete(@NewShortcut)
      end

    end

    # Class that deletes a Shortcut
    class UAO_DeleteShortcut < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iShortcut* (_Shortcut_): The Shortcut to delete
      def initialize(iController, iShortcut)
        super(iController)

        @Shortcut = iShortcut
      end

      # Perform the operation
      def doOperation
        logDebug "UAO_DeleteShortcut #{@Shortcut.Metadata['title']}"
        @Controller._UNDO_deleteShortcut(@Shortcut)
        @Controller.notifyShortcutDelete(@Shortcut)
      end

      # Undo the operation
      def undoOperation
        logDebug "UNDO - UAO_DeleteShortcut #{@Shortcut.Metadata['title']}"
        @Controller._UNDO_addShortcut(@Shortcut)
        @Controller.notifyShortcutCreate(@Shortcut)
      end

    end

    # Class that modifies a Shortcut
    class UAO_UpdateShortcut < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iShortcut* (_Shortcut_): The Shortcut being modified
      # * *iNewContent* (_Object_): The new Content
      # * *iNewMetadata* (<em>map<String,Object></em>): The new Metadata
      # * *iNewTags* (<em>map<Tag,nil></em>): The new Tags
      def initialize(iController, iShortcut, iNewContent, iNewMetadata, iNewTags)
        super(iController)

        @Shortcut = iShortcut
        if (iShortcut.Content != iNewContent)
          @OldContent = iShortcut.Content
          @NewContent = iNewContent
        else
          @OldContent = nil
          @NewContent = nil
        end
        if (iShortcut.Metadata != iNewMetadata)
          @OldMetadata = iShortcut.Metadata
          @NewMetadata = iNewMetadata
        else
          @OldMetadata = nil
          @NewMetadata = nil
        end
        if (iShortcut.Tags != iNewTags)
          # Here we clone as the assignment is not made by replacing the Shortcut.Tags property, but by changing the current one instead.
          @OldTags = iShortcut.Tags.clone
          @NewTags = iNewTags
        else
          @OldTags = nil
          @NewTags = nil
        end
      end

      # Perform the operation
      def doOperation
        logDebug "UAO_ModifySC #{@Shortcut.Metadata['title']}"
        if (@NewContent != nil)
          @Shortcut._UNDO_setContent(@NewContent)
        end
        if (@NewMetadata != nil)
          @Shortcut._UNDO_setMetadata(@NewMetadata)
        end
        if ((@NewContent != nil) or
            (@NewMetadata != nil))
          @Controller.notifyShortcutDataUpdate(@Shortcut, @OldContent, @OldMetadata)
        end
        if (@NewTags != nil)
          lOldTags = @Shortcut.Tags.clone
          @Shortcut._UNDO_setTags(@NewTags)
          @Controller.notifyShortcutTagsUpdate(@Shortcut, lOldTags)
        end
      end

      # Undo the operation
      def undoOperation
        logDebug "UNDO - UAO_ModifySC #{@Shortcut.Metadata['title']}"
        if (@OldContent != nil)
          @Shortcut._UNDO_setContent(@OldContent)
        end
        if (@OldMetadata != nil)
          @Shortcut._UNDO_setMetadata(@OldMetadata)
        end
        if ((@OldContent != nil) or
            (@OldMetadata != nil))
          @Controller.notifyShortcutDataUpdate(@Shortcut, @NewContent, @NewMetadata)
        end
        if (@OldTags != nil)
          lOldTags = @Shortcut.Tags.clone
          @Shortcut._UNDO_setTags(@OldTags)
          @Controller.notifyShortcutTagsUpdate(@Shortcut, lOldTags)
        end
      end

    end

    # Class that sets current file as modified
    class UAO_SetFileModified < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      def initialize(iController)
        super(iController)

        @OldModifiedFlag = @Controller.CurrentOpenedFileModified
      end

      # Perform the operation
      def doOperation
        logDebug 'UAO_SetFileModified'
        @Controller._UNDO_setCurrentOpenedFileModified(true)
        @Controller.notifyCurrentOpenedFileUpdate
      end

      # Undo the operation
      def undoOperation
        logDebug 'UNDO - UAO_SetFileModified'
        @Controller._UNDO_setCurrentOpenedFileModified(@OldModifiedFlag)
        @Controller.notifyCurrentOpenedFileUpdate
      end

    end

    # Class that changes the name of the opened file
    class UAO_ChangeFile < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iNewFileName* (_String_): The new file name
      def initialize(iController, iNewFileName)
        super(iController)

        @OldFileName = @Controller.CurrentOpenedFileName
        @OldFileModified = @Controller.CurrentOpenedFileModified
        @NewFileName = iNewFileName
      end

      # Perform the operation
      def doOperation
        logDebug "UAO_ChangeFile #{@NewFileName}"
        @Controller._UNDO_setCurrentOpenedFileName(@NewFileName)
        @Controller._UNDO_setCurrentOpenedFileModified(false)
        @Controller.notifyCurrentOpenedFileUpdate
      end

      # Undo the operation
      def undoOperation
        logDebug "UNDO - UAO_ChangeFile #{@NewFileName}"
        @Controller._UNDO_setCurrentOpenedFileName(@OldFileName)
        @Controller._UNDO_setCurrentOpenedFileModified(@OldFileModified)
        @Controller.notifyCurrentOpenedFileUpdate
      end

    end

  end

end
