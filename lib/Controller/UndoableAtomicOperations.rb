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

    # Class that deletes a Tag
    class UAO_DeleteTag < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iTag* (_Tag_): The Tag to delete
      def initialize(iController, iTag)
        super(iController)

        @ParentTagID = iTag.Parent.getUniqueID.clone
        @Tag = iTag.clone(nil)
      end

      # Perform the operation
      def doOperation
        puts "UAO_DeleteTag #{@Tag.Name}"
        lParentTag = @Controller.findTag(@ParentTagID)
        lOldChildrenList = lParentTag.Children.clone
        lParentTag.deleteChildTag_UNDO(@Tag.Name)
        @Controller.notifyTagChildrenUpdate(lParentTag, lOldChildrenList)
      end

      # Undo the operation
      def undoOperation
        puts "UNDO - UAO_DeleteTag #{@Tag.Name}"
        lParentTag = @Controller.findTag(@ParentTagID)
        lOldChildrenList = lParentTag.Children.clone
        @Tag.clone(lParentTag)
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

        @NewShortcutSerializedData = iShortcut.getSerializedData.clone
        @ShortcutID = iShortcut.getUniqueID
      end

      # Perform the operation
      def doOperation
        puts "UAO_AddNewShortcut #{@NewShortcutSerializedData.getName}"
        lNewShortcut = @NewShortcutSerializedData.clone.createShortcut(@Controller.RootTag, @Controller.TypesPlugins)
        @Controller.addShortcut_UNDO(lNewShortcut)
        @Controller.notifyShortcutAdd(lNewShortcut)
      end

      # Undo the operation
      def undoOperation
        puts "UNDO - UAO_AddNewShortcut #{@NewShortcutSerializedData.getName}"
        lAddedShortcut = @Controller.findShortcut(@ShortcutID)
        @Controller.deleteShortcut_UNDO(@ShortcutID)
        @Controller.notifyShortcutDelete(lAddedShortcut)
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

        @NewShortcutSerializedData = iShortcut.getSerializedData(false).clone
        @ShortcutID = iShortcut.getUniqueID
      end

      # Perform the operation
      def doOperation
        puts "UAO_DeleteShortcut #{@NewShortcutSerializedData.getName}"
        lShortcut = @Controller.findShortcut(@ShortcutID)
        @Controller.deleteShortcut_UNDO(@ShortcutID)
        @Controller.notifyShortcutDelete(lShortcut)
      end

      # Undo the operation
      def undoOperation
        puts "UNDO - UAO_DeleteShortcut #{@NewShortcutSerializedData.getName}"
        lNewShortcut = @NewShortcutSerializedData.clone.createShortcut(@Controller.RootTag, @Controller.TypesPlugins)
        @Controller.addShortcut_UNDO(lNewShortcut)
        @Controller.notifyShortcutAdd(lNewShortcut)
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
          @OldTags = []
          iShortcut.Tags.each do |iTag, iNil|
            @OldTags << iTag.getUniqueID
          end
          @NewTags = []
          iNewTags.each do |iTag, iNil|
            @NewTags << iTag.getUniqueID
          end
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
            lOldTags = lShortcut.Tags
            lNewTags = {}
            @NewTags.each do |iTagID|
              lTag = @Controller.findTag(iTagID)
              if (lTag == nil)
                puts "!!! Tag ID #{iTagID} should exist, but the controller returned nil. Bug ?"
              else
                lNewTags[lTag] = nil
              end
            end
            lShortcut.setTags_UNDO(lNewTags)
            @Controller.notifyShortcutTagsUpdate(lShortcut, lOldTags)
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
            lNewTags = lShortcut.Tags
            lOldTags = {}
            @OldTags.each do |iTagID|
              lTag = @Controller.findTag(iTagID)
              if (lTag == nil)
                puts "!!! Tag ID #{iTagID} should exist, but the controller returned nil. Bug ?"
              else
                lOldTags[lTag] = nil
              end
            end
            lShortcut.setTags_UNDO(lOldTags)
            @Controller.notifyShortcutTagsUpdate(lShortcut, lNewTags)
          end
        end
      end

    end

    # Class that modifies a Tag
    class UAO_ModifyTag < UndoableAtomicOperation

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *iTag* (_Tag_): The Tag being modified
      # * *iNewName* (_String_): The new name
      # * *iNewIcon* (<em>Wx::Bitmap</em>): The new icon (can be nil)
      def initialize(iController, iTag, iNewName, iNewIcon)
        super(iController)

        @OldTagID = iTag.getUniqueID
        @NewTagID = iTag.Parent.getUniqueID + [iNewName]
        @OldName = iTag.Name.clone
        @NewName = iNewName.clone
        @OldIcon = nil
        if (iTag.Icon != nil)
          @OldIcon = iTag.Icon.clone
        end
        @NewIcon = nil
        if (iNewIcon != nil)
          @NewIcon = iNewIcon.clone
        end
      end

      # Perform the operation
      def doOperation
        # Retrieve the Tag
        lTag = @Controller.findTag(@OldTagID)
        puts "UAO_ModifyTag #{lTag.Name}"
        if (lTag != nil)
          lTag.setName_UNDO(@NewName.clone)
          lNewIcon = nil
          if (@NewIcon != nil)
            lNewIcon = @NewIcon.clone
          end
          lTag.setIcon_UNDO(lNewIcon)
          @Controller.notifyTagDataUpdate(lTag, @OldTagID, @OldName, @OldIcon)
        end
      end

      # Undo the operation
      def undoOperation
        # Retrieve the Shortcut
        lTag = @Controller.findTag(@NewTagID)
        puts "UNDO - UAO_ModifyTag #{lTag.Name}"
        if (lTag != nil)
          lTag.setName_UNDO(@OldName.clone)
          lOldIcon = nil
          if (@OldIcon != nil)
            lOldIcon = @OldIcon.clone
          end
          lTag.setIcon_UNDO(lOldIcon)
          @Controller.notifyTagDataUpdate(lTag, @NewTagID, @NewName, @NewIcon)
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

        # This class is a little bit different: it stores references to Tags/Shortcuts inside its own saved data.
        # The reason why it works is that all those objects will never be referenced by anyone outside them.
        # Therefore we can keep the references knowing that we save every Tag/Shortcut.
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
