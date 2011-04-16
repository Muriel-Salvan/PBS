#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Paste

      # Command that pastes an object from the clipboard
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *tag* (_Tag_): Tag in which we paste the clipboard's content (can be the Root tag)
      def execute(ioController, iParams)
        lSelectedTag = iParams[:tag]
        # We are sure that we can paste, everything is already in the ioController.Clipboard_* variables.
        ioController.undoableOperation("Paste #{ioController.Clipboard_SerializedSelection.getDescription} in #{lSelectedTag.Name}") do
          ioController.Clipboard_SerializedSelection.createSerializedTagsShortcuts(ioController, lSelectedTag, ioController.CopiedSelection)
        end
        # In case of Cut, we notify the sender back.
        if (ioController.Clipboard_CopyMode == Wx::ID_CUT)
          # Replace data in the clipboard with an acknowledgement
          lClipboardData = Tools::DataObjectSelection.new
          lClipboardData.setData(Wx::ID_DELETE, ioController.Clipboard_CopyID, nil)
          Wx::Clipboard.open do |ioClipboard|
            ioClipboard.data = lClipboardData
          end
        end
      end

    end

  end

end
