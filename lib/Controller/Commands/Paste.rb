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
          lClipboardData = Tools::DataObjectTag.new
          if iClipboard.supported?(lClipboardData.get_format)
            # OK, this is data we understand. Get it.
            iClipboard.get_data(lClipboardData)
            lDataID, lDataContent = Marshal.load(lClipboardData.Data)
            case lDataID
            when ID_TAG
              # A Tag is in the clipboard
              # First check that the child tag does not exist already
              lChildName = Tag.getSerializedTagName(lDataContent)
              lFound = false
              lSelectedTag.Children.each do |iChildTag|
                if (iChildTag.Name == lChildName)
                  lFound = true
                  break
                end
              end
              if (lFound)
                puts "!!! A Tag named #{lChildName} already exists as a sub-Tag of #{lSelectedTag.Name}"
              else
                undoableOperation("Paste Tag #{lChildName} in #{lSelectedTag.Name}") do
                  addNewTag(lSelectedTag, Tag.createTagFromSerializedData(nil, lDataContent))
                  setCurrentFileModified
                end
              end
            when ID_SHORTCUT
              lShortcutName = Shortcut.getSerializedShortcutName(lDataContent)
              # A Shortcut is in the clipboard
              undoableOperation("Paste Shortcut #{lShortcutName} in #{lSelectedTag.Name}") do
                lNewSC = Shortcut.createShortcutFromSerializedData(@RootTag, @TypesPlugins, lDataContent, true)
                # First check if this Shortcut already exists or not.
                lExistingSC = findShortcut(lNewSC.getUniqueID)
                if (lExistingSC == nil)
                  # It is a brand new Shortcut. Just add it simply, by adding the selected Tag among its ones.
                  lNewSC.Tags[lSelectedTag] = nil
                  addNewShortcut(lNewSC)
                  setCurrentFileModified
                else
                  # It already exists: just add lSelectedTags among the Tags if it is not already present.
                  if (!lExistingSC.Tags.has_key?(lSelectedTag))
                    lNewTags = lExistingSC.Tags.clone
                    lNewTags[lSelectedTag] = nil
                    modifyShortcut(lExistingSC, lExistingSC.Content, lExistingSC.Metadata, lNewTags)
                    setCurrentFileModified
                  end
                end
              end
            else
              puts "!!! Clipboard contains unknown data ID: #{lDataID}. Ignoring it."
            end
          else
            puts '!!! Clipboard does not contain data readable for PBS.'
          end
        end
      end

    end

  end

end
