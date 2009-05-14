#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Delete

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdDelete(iCommands)
        iCommands[Wx::ID_DELETE] = {
          :title => 'Delete',
          :help => 'Delete selection',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdDelete,
          :accelerator => [ Wx::MOD_NONE, Wx::K_DELETE ]
        }
      end

      # Command that pastes an object from the clipboard
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      # ** *objectID* (_Integer_): ID of the object to be deleted
      # ** *object* (_Object_): Object to be deleted
      def cmdDelete(iParams)
        lWindow = iParams[:parentWindow]
        lObjectID = iParams[:objectID]
        lObject = iParams[:object]
        case lObjectID
        when ID_TAG
          # Get the list of Tags we are going to delete
          lTagsToDelete = [lObject]
          lObject.traverse do |iChildTag|
            lTagsToDelete << iChildTag
          end
          # Check if there are some Shortcuts belonging to those Tags only
          # The list of Shortcuts that have only Tags from the ones to be deleted
          lDeletableShortcuts = []
          # The list of Shortcuts that have at least 1 of the Tags to be deleted, but are not in the lDeletableShortcuts list
          lConcernedShortcuts = []
          @ShortcutsList.each do |iSC|
            # Check if there is at least 1 Tag belonging to lTagsToDelete, and no other Tag not belonging to lTagsToDelete
            lTagPresent = false
            lForeignTagPresent = false
            iSC.Tags.each do |iTag, iNil|
              if (lTagsToDelete.include?(iTag))
                lTagPresent = true
                if (lForeignTagPresent)
                  break
                end
              else
                lForeignTagPresent = true
                if (lTagPresent)
                  break
                end
              end
            end
            if (lTagPresent)
              if (!lForeignTagPresent)
                lDeletableShortcuts << iSC
              else
                lConcernedShortcuts << iSC
              end
            end
          end
          undoableOperation("Delete Tag #{lObject.Name}") do
            if (!lDeletableShortcuts.empty?)
              # First ask if we also want to delete Shortcuts belonging to this Tag and its sub-Tags only
              case Wx::MessageDialog.new(lWindow,
                  "Do you also want to delete the #{lDeletableShortcuts.size} orphan Shortcuts that will have no Tag anymore after deleting this Tag and its sub-Tags ?\nYou will still be able to undo the operation in case of mistake.",
                  :caption => 'Confirm delete orphan Shortcuts',
                  :style => Wx::YES_NO|Wx::NO_DEFAULT|Wx::ICON_EXCLAMATION
                ).show_modal
              when Wx::ID_YES
                # Delete Shortcuts present in lShortcuts
                lDeletableShortcuts.each do |iSC|
                  deleteShortcut(iSC)
                end
              when Wx::ID_NO
                # Delete the Tags references from each Shortcut
                lDeletableShortcuts.each do |iSC|
                  lNewTags = iSC.Tags.clone
                  lNewTags.delete_if do |iTag, iNil|
                    lTagsToDelete.include?(iTag)
                  end
                  modifyShortcut(iSC, iSC.Content, iSC.Metadata, lNewTags)
                end
              end
            end
            # Modify concerned Shortcuts
            lConcernedShortcuts.each do |iSC|
              lNewTags = iSC.Tags.clone
              lNewTags.delete_if do |iTag, iNil|
                lTagsToDelete.include?(iTag)
              end
              modifyShortcut(iSC, iSC.Content, iSC.Metadata, lNewTags)
            end
            # Then we delete the Tags for real
            deleteTag(lObject)
          end
        when ID_SHORTCUT
          # First check if this Shortcut is present in other Tags
          lPerformDelete = true
          if (lObject.Tags.size > 1)
            case Wx::MessageDialog.new(lWindow,
                "This Shortcut has several Tags. Are you sure you want to delete it ?",
                :caption => 'Confirm delete Shortcut',
                :style => Wx::YES_NO|Wx::NO_DEFAULT|Wx::ICON_EXCLAMATION
              ).show_modal
            when Wx::ID_NO
              lPerformDelete = false
            end
          end
          if (lPerformDelete)
            undoableOperation("Delete Shortcut #{lObject.Metadata['title']}") do
              deleteShortcut(lObject)
            end
          end
        else
          puts "!!! Unknown ID of selection: #{lObjectID}. Bug ?"
        end
      end

    end

  end

end
