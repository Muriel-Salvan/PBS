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
          :help => 'Paste clipboard\'s content',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Paste.png"),
          :method => :cmdPaste,
          :accelerator => [ Wx::MOD_CMD, 'v'[0] ]
        }
      end

      # Command that pastes an object from the clipboard
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *tag* (_Tag_): Tag in which we paste the clipboard's content (can be the Root tag)
      def cmdPaste(iParams)
        lSelectedTag = iParams[:tag]
        # We are sure that we can paste, everything is already in the @Clipboard_* variables.
        undoableOperation("Paste #{@Clipboard_SerializedSelection.getDescription} in #{lSelectedTag.Name}") do
          @Clipboard_SerializedSelection.createSerializedTagsShortcuts(self, lSelectedTag, @CopiedSelection)
        end
        # In case of Cut, we notify the sender back.
        if (@Clipboard_CopyMode == Wx::ID_CUT)
          # Replace data in the clipboard with an acknowledgement
          lClipboardData = Tools::DataObjectSelection.new
          lClipboardData.setData(Wx::ID_DELETE, @Clipboard_CopyID, nil)
          Wx::Clipboard.open do |ioClipboard|
            ioClipboard.data = lClipboardData
          end
        end
      end

    end

  end

end
