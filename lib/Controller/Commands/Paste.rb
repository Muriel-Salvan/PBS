#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Paste

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdPaste(iCommands)
        iCommands[Wx::ID_PASTE] = {
          :title => 'Paste',
          :help => 'Past clipboard\'s content',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Paste.png"),
          :method => :cmdPaste,
          :accelerator => [ Wx::MOD_CMD, 'v'[0] ]
        }
      end

      # Command that pastes an object from the clipboard
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *tag* (_Tag_): Tag in which we paste the clipboard's content
      def cmdPaste(iParams)
        lSelectedTag = iParams[:tag]
        # Test what is inside the clipboard
        Wx::Clipboard.open do |iClipboard|
          if (iClipboard.supported?(Tools::DataObjectSelection.getDataFormat))
            # OK, this is data we understand. Get it.
            lClipboardData = Tools::DataObjectSelection.new
            iClipboard.get_data(lClipboardData)
            lCopyType, lCopyID, lSerializedTags, lSerializedShortcuts = lClipboardData.getData
            # Before trying anything, we must ensure that in case of a Cut/Paste operation on our own data, we are not trying to paste to one of the selected sub-Tags.
            lCancel = false
            if ((lCopyType == Wx::ID_CUT) and
                (lCopyID == @CopiedID))
              # We are cutting something from our own application.
              # Check that lSelectedTag is not part of any of the primary selected Tags' children (recursively).
              lPasteIntoTagID = lSelectedTag.getUniqueID
              lFound = false
              @CopiedSelection.SelectedPrimaryTags.each do |iSelectedTagID|
                if (lPasteIntoTagID[0..iSelectedTagID.size - 1] == iSelectedTagID)
                  lFound = true
                  break
                end
              end
              if (lFound)
                puts "The selected Tag for pasting data (#{lSelectedTag.Name}) is a sub-Tag of the data you are trying to move. Please select a Tag that is not part of the cut data."
                lCancel = true
              end
            end
            if (!lCancel)
              undoableOperation("Paste #{Tools::MultipleSelection.getDescription(lSerializedTags, lSerializedShortcuts)} in #{lSelectedTag.Name}") do
                # First check each selected Tag
                lSerializedTags.each do |iSerializedTag|
                  # Deserialize data in separate objects, ready to be merged after.
                  lNewShortcutsList = []
                  lNewRootTag = iSerializedTag.createTag(nil, @TypesPlugins, lNewShortcutsList)
                  addMergeTagsShortcuts(lNewRootTag, lNewShortcutsList, lSelectedTag)
                end
                # Then check selected Shortcuts
                if (!lSerializedShortcuts.empty?)
                  # Put them in a brand new list first
                  lNewShortcuts = []
                  lSerializedShortcuts.each do |iSerializedData|
                    # Check for already created Shortcuts (in case we selected twice the same Shortcut from different Tags)
                    lExistingSC = nil
                    lNewID = iSerializedData.getUniqueID
                    lNewShortcuts.each do |iExistingSC|
                      if (iExistingSC.getUniqueID == lNewID)
                        lExistingSC = iExistingSC
                        break
                      end
                    end
                    if (lExistingSC != nil)
                      # Add lSelectedTag to the list of Tags already part of lExistingSC
                      lExistingSC.Tags[lSelectedTag] = nil
                    else
                      # A new Shortcut
                      lNewShortcut = iSerializedData.createShortcut(nil, @TypesPlugins)
                      # Set the Tag
                      lNewShortcut.Tags[lSelectedTag] = nil
                      # Add it
                      lNewShortcuts << lNewShortcut
                    end
                  end
                  # Then merge Shortcuts
                  mergeShortcuts(lNewShortcuts, @RootTag)
                end
                # Mark as modified
                setCurrentFileModified
              end
              # In case of Cut, we notify the sender back.
              if (lCopyType == Wx::ID_CUT)
                # Replace data in the clipboard with an acknowledgement
                lClipboardData = Tools::DataObjectSelection.new
                lClipboardData.setData(Wx::ID_DELETE, lCopyID, nil, nil)
                Wx::Clipboard.open do |ioClipboard|
                  ioClipboard.data = lClipboardData
                end
              end
            end
          else
            puts '!!! Clipboard does not contain data readable for PBS.'
          end
        end
      end

    end

  end

end
