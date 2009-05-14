#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every class defining Undoable Atomic Operations, that is simple operations on the data that are protected with do/undo methods.
  # These classes are used with a set of methods also defined in this module.
  # Those methods/classes should be exclusively used by Actions methods, themselves invoked by the Commands.
  module UndoableAtomicOperations

    # Base class for every undoable atomic operation.
    # Here are some considerations to ENSURE when coding Undo/Redo atomic operations:
    # * Objects saved during initialization that will serve for the Undo method (ie. objects reflecting the old state) HAVE to never be modified by any possible past or future operation (even by operations not part of this atomic operation). The best way to ensure that is to clone them when saved, and also when used.
    # * The same goes for objects saved to ensure the Redo method (ie. objects reflecting the new state), for the same reasons.
    # To be more convinced, check this use case:
    # 01. Do Create New Shortcut: SC1.title = 'A' ( Save 01.NewSC = SC1)
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
    class UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller giving access to the model
      def initialize(iController)
        @Controller = iController
      end

    end

    # Class that adds a new Tag as a child of an existing one
    class UAO_AddNewTag < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *ioParentTag* (_Tag_): The Tag that will receive the new one
      # * *iChildTag* (_Tag_): The new Tag to add
      def initialize(iController, ioParentTag, iChildTag)
        super(iController)

        @ParentTagID = ioParentTag.getUniqueID.clone
        @ChildTag = iChildTag.clone(nil)
      end

      # Perform the operation
      def doOperation
        puts "UAO_AddNewTag #{@ChildTag.Name}"
        lParentTag = @Controller.findTag(@ParentTagID)
        lOldChildrenList = lParentTag.Children.clone
        @ChildTag.clone(lParentTag)
        @Controller.notifyTagChildrenUpdate(lParentTag, lOldChildrenList)
      end

      # Undo the operation
      def undoOperation
        puts "UNDO - UAO_AddNewTag #{@ChildTag.Name}"
        lParentTag = @Controller.findTag(@ParentTagID)
        lOldChildrenList = lParentTag.Children.clone
        lParentTag.deleteChildTag_UNDO(@ChildTag.Name)
        @Controller.notifyTagChildrenUpdate(lParentTag, lOldChildrenList)
      end

    end

    # Class that adds a new Shortcut
    class UAO_AddNewShortcut < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iShortcut* (_Shortcut_): The Shortcut to add
      def initialize(iController, iShortcut)
        super(iController)

        @ShortcutToAdd = iShortcut.clone
      end

      # Perform the operation
      def doOperation
        puts "UAO_AddNewShortcut #{@ShortcutToAdd.Metadata['title']}"
        lNewShortcut = @ShortcutToAdd.clone
        @Controller.addShortcut_UNDO(lNewShortcut)
        @Controller.notifyShortcutAdd(lNewShortcut)
      end

      # Undo the operation
      def undoOperation
        puts "UNDO - UAO_AddNewShortcut #{@ShortcutToAdd.Metadata['title']}"
        lAddedShortcut = @Controller.findShortcut(@ShortcutToAdd.getUniqueID)
        @Controller.deleteShortcut_UNDO(@ShortcutToAdd.getUniqueID)
        @Controller.notifyShortcutDelete(lAddedShortcut)
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
        puts 'UAO_SetFileModified'
        @Controller.setCurrentOpenedFileModified_UNDO(true)
        @Controller.notifyCurrentOpenedFileUpdate
      end

      # Undo the operation
      def undoOperation
        puts 'UNDO - UAO_SetFileModified'
        @Controller.setCurrentOpenedFileModified_UNDO(@OldModifiedFlag)
        @Controller.notifyCurrentOpenedFileUpdate
      end

    end

    # Class that modifies a Shortcut
    class UAO_ModifySC < UndoableAtomicOperation

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

        @OldShortcutID = iShortcut.getUniqueID
        @NewShortcutID = Shortcut.getUniqueID(iNewContent, iNewMetadata)
        if (iShortcut.Content != iNewContent)
          @OldContent = iShortcut.Content.clone
          @NewContent = iNewContent.clone
        else
          @OldContent = nil
          @NewContent = nil
        end
        if (iShortcut.Metadata != iNewMetadata)
          @OldMetadata = iShortcut.Metadata.clone
          @NewMetadata = iNewMetadata.clone
        else
          @OldMetadata = nil
          @NewMetadata = nil
        end
        if (iShortcut.Tags != iNewTags)
          @OldTags = iShortcut.Tags.clone
          @NewTags = iNewTags.clone
        else
          @OldTags = nil
          @NewTags = nil
        end
      end

      # Perform the operation
      def doOperation
        # Retrieve the Shortcut
        lShortcut = @Controller.findShortcut(@OldShortcutID)
        puts "UAO_ModifySC #{lShortcut.Metadata['title']}"
        if (lShortcut != nil)
          if (@NewContent != nil)
            lShortcut.setContent_UNDO(@NewContent.clone)
          end
          if (@NewMetadata != nil)
            lShortcut.setMetadata_UNDO(@NewMetadata.clone)
          end
          if ((@NewContent != nil) or
              (@NewMetadata != nil))
            @Controller.notifyShortcutDataUpdate(lShortcut, @OldShortcutID, @OldContent, @OldMetadata)
          end
          if (@NewTags != nil)
            lShortcut.setTags_UNDO(@NewTags.clone)
            @Controller.notifyShortcutTagsUpdate(lShortcut, @OldTags)
          end
        end
      end

      # Undo the operation
      def undoOperation
        # Retrieve the Shortcut
        lShortcut = @Controller.findShortcut(@NewShortcutID)
        puts "UNDO - UAO_ModifySC #{lShortcut.Metadata['title']}"
        if (lShortcut != nil)
          if (@OldContent != nil)
            lShortcut.setContent_UNDO(@OldContent.clone)
          end
          if (@OldMetadata != nil)
            lShortcut.setMetadata_UNDO(@OldMetadata.clone)
          end
          if ((@OldContent != nil) or
              (@OldMetadata != nil))
            @Controller.notifyShortcutDataUpdate(lShortcut, @NewShortcutID, @NewContent, @NewMetadata)
          end
          if (@OldTags != nil)
            lShortcut.setTags_UNDO(@OldTags.clone)
            @Controller.notifyShortcutTagsUpdate(lShortcut, @NewTags)
          end
        end
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
        puts "UAO_ChangeFile #{@NewFileName}"
        @Controller.setCurrentOpenedFileName_UNDO(@NewFileName)
        @Controller.setCurrentOpenedFileModified_UNDO(false)
        @Controller.notifyCurrentOpenedFileUpdate
      end

      # Undo the operation
      def undoOperation
        puts "UNDO - UAO_ChangeFile #{@NewFileName}"
        @Controller.setCurrentOpenedFileName_UNDO(@OldFileName)
        @Controller.setCurrentOpenedFileModified_UNDO(@OldFileModified)
        @Controller.notifyCurrentOpenedFileUpdate
      end

    end

    # Class that changes all Shortcuts and Tags data
    class UAO_ReplaceAll < UndoableAtomicOperation

      include Tools

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iNewRootTag* (_Tag_): The new root tag
      # * *iNewShortcutsList* (<em>list<Shortcut></em>): The new Shortcuts list
      def initialize(iController, iNewRootTag, iNewShortcutsList)
        super(iController)

        # Be careful when cloning, as the Shortcuts list contains references to Tags that are among iNewRootTag
        @OldRootTag, @OldShortcutsList = cloneTagsShortcuts(@Controller.RootTag, @Controller.ShortcutsList)
        @NewRootTag, @NewShortcutsList = cloneTagsShortcuts(iNewRootTag, iNewShortcutsList)
      end

      # Perform the operation
      def doOperation
        puts 'UAO_ReplaceAll'
        lNewRootTag, lNewShortcutsList = cloneTagsShortcuts(@NewRootTag, @NewShortcutsList)
        @Controller.setRootTag_UNDO(lNewRootTag)
        @Controller.setShortcutsList_UNDO(lNewShortcutsList)
        @Controller.notifyReplaceAll
      end

      # Undo the operation
      def undoOperation
        puts 'UNDO - UAO_ReplaceAll'
        lOldRootTag, lOldShortcutsList = cloneTagsShortcuts(@OldRootTag, @OldShortcutsList)
        @Controller.setRootTag_UNDO(lOldRootTag)
        @Controller.setShortcutsList_UNDO(lOldShortcutsList)
        @Controller.notifyReplaceAll
      end

    end

    # Add a new atomic operation in the current undoable transaction
    #
    # Parameters:
    # * *iUndoableAtomicOperation* (_UndoableAtomicOperation_): The atomic operation
    def atomicOperation(iUndoableAtomicOperation)
      @CurrentUndoableOperation.AtomicOperations << iUndoableAtomicOperation
      # Perform it right now
      iUndoableAtomicOperation.doOperation
    end

  end

end
