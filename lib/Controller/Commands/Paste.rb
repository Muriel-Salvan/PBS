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
            undoableOperation("Paste #{Tools::MultipleSelection.getDescription(lSerializedTags, lSerializedShortcuts)} in #{lSelectedTag.Name}") do
              mergeSerializedTagsShortcuts(lSelectedTag, lSerializedTags, lSerializedShortcuts)
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
          else
            puts '!!! Clipboard does not contain data readable for PBS.'
          end
        end
      end

    end

  end

end
