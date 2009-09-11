#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Delete

      # Command that pastes an object from the clipboard
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      # ** *selection* (_MultipleSelection_): the current selection.
      # ** *deleteTaggedShortcuts* (_Boolean_): Do we delete systematically tagged Shortcuts ? (can be nil to prompt the user about it)
      # ** *deleteOrphanShortcuts* (_Boolean_): Do we delete systematically orphan Shortcuts ? (can be nil to prompt the user about it)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        lSelection = iParams[:selection]
        lForceDeleteTaggedShortcuts = iParams[:deleteTaggedShortcuts]
        lForceDeleteOrphanShortcuts = iParams[:deleteOrphanShortcuts]
        ioController.undoableOperation("Delete #{lSelection.getDescription}") do

          # ###########################
          # 1 - We delete every selected Shortcut (primary and secondary)
          # ###########################
          # For each Shortcut, get the set of Tags to remove from it, and compute the new set of Tags
          # map< Shortcut, [ map< Tag, nil >, map< Tag, nil > ] >
          lSelectedShortcuts = {}
          (lSelection.SelectedPrimaryShortcuts + lSelection.SelectedSecondaryShortcuts).each do |iSelectedShortcutInfo|
            iSelectedShortcut, iParentTag = iSelectedShortcutInfo
            if (lSelectedShortcuts[iSelectedShortcut] == nil)
              lSelectedShortcuts[iSelectedShortcut] = [ {}, nil ]
            end
            lSelectedShortcuts[iSelectedShortcut][0][iParentTag] = nil
          end
          if (!lSelectedShortcuts.empty?)
            lExistOrphanShortcuts = false
            lExistTaggedShortcuts = false
            # First check if we ask the question whether to remove empty tagged Shortcuts or not.
            # Do we have some Shortcuts that would be without Tags after deletion ?
            lSelectedShortcuts.each do |iSC, ioTagsInfo|
              iSelectedTagsSet, iNewTagsSet = ioTagsInfo
              if (!iSC.Tags.empty?)
                lExistTaggedShortcuts = true
                # Compute the new Tags
                lNewTags = {}
                iSC.Tags.each do |iTag, iNil|
                  if (!iSelectedTagsSet.has_key?(iTag))
                    lNewTags[iTag] = nil
                  end
                end
                if (lNewTags.empty?)
                  lExistOrphanShortcuts = true
                end
                # Remember it
                ioTagsInfo[1] = lNewTags
              end
            end
            # Now ask questions if they are not forced by the parameters
            lDeleteTaggedShortcuts = false
            if (lForceDeleteTaggedShortcuts != nil)
              lDeleteTaggedShortcuts = lForceDeleteTaggedShortcuts
            else
              if (lExistTaggedShortcuts)
                showModal(Wx::MessageDialog, lWindow,
                  "Do you want to delete completely the selected Shortcuts ?\nIf No, this will just untag them accordingly.",
                  :caption => 'Confirm delete Shortcut',
                  :style => Wx::YES_NO|Wx::NO_DEFAULT|Wx::ICON_EXCLAMATION
                ) do |iModalResult, iDialog|
                  case iModalResult
                  when Wx::ID_YES
                    lDeleteTaggedShortcuts = true
                  end
                end
              end
            end
            lDeleteOrphanShortcuts = false
            if (lForceDeleteOrphanShortcuts != nil)
              lDeleteOrphanShortcuts = lForceDeleteOrphanShortcuts
            else
              if ((!lDeleteTaggedShortcuts) and
                  (lExistOrphanShortcuts))
                showModal(Wx::MessageDialog, lWindow,
                  "Do you want to delete the selected Shortcuts that will have no Tag anymore ?",
                  :caption => 'Confirm delete orphan Shortcuts',
                  :style => Wx::YES_NO|Wx::NO_DEFAULT|Wx::ICON_EXCLAMATION
                ) do |iModalResult, iDialog|
                  case iModalResult
                  when Wx::ID_YES
                    lDeleteOrphanShortcuts = true
                  end
                end
              end
            end
            # Now perform what has been decided on Shortcuts
            lSelectedShortcuts.each do |iSC, iTagsInfo|
              iSelectedTagsSet, iNewTagsSet = iTagsInfo
              # We delete this Shortcut if:
              # * It has no Tag, OR
              # * We want to delete tagged Shortcuts, OR
              # * We want to delete orphan Shortcuts AND it the new Tags set is empty
              if ((iSC.Tags.empty?) or
                  (lDeleteTaggedShortcuts) or
                  ((lDeleteOrphanShortcuts) and
                   (iNewTagsSet.empty?)))
                # Delete iSC for real
                ioController.deleteShortcut(iSC)
              else
                # Here, we are sure that this Shortcut:
                # * Has at least 1 Tag, AND
                # * We refuse to delete systematically tagged Shortcuts, AND
                # * We refuse to delete orphan Shortcuts, OR it has some remaining Tags even after deleting selected ones.
                # So here we just replace its Tags set with the new one computed previously.
                ioController.updateShortcut(iSC, iSC.Content, iSC.Metadata, iNewTagsSet)
              end
            end
          end

          # ###########################
          # 2 - We delete every selected Tag (primary is enough, as secondary will be deleted recursively)
          # ###########################
          if (!lSelection.SelectedPrimaryTags.empty?)
            # We first have to select Tags that do not have other primary selected Tags among their predecessor (as the primary selected predecessor will also delete its children Tags)
            # list< Tag >
            lTagsToDelete = []
            lSelection.SelectedPrimaryTags.each do |iTag|
              # If this Tag is not already a sub-Tag (recursively) of an already selected one, add it
              lFound = false
              lCheckTag = iTag
              while (lCheckTag != nil)
                if (lTagsToDelete.include?(lCheckTag))
                  # Already present
                  lFound = true
                  break
                end
                lCheckTag = lCheckTag.Parent
              end
              if (!lFound)
                # No parent Tag of lTag is present in lTagsToDelete.
                # Now we have to make sure that existing Tags are not part of the sub-Tags of iTag also, and delete them if it is the case.
                # Delete Tags from the list that are sub-Tags of iTag
                lTagsToDelete.delete_if do |iSelectedTag|
                  iSelectedTag.subTagOf?(iTag)
                end
                # Add the Tag to be deleted
                lTagsToDelete << iTag
              end
            end
            # Now we can delete safely every Tag from lTagsToDelete
            lTagsToDelete.each do |iTag|
              ioController.deleteTag(iTag)
            end
          end
        end
      end

    end

  end

end
