#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Cut

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdCut(iCommands)
        iCommands[Wx::ID_CUT] = {
          :title => 'Cut',
          :help => 'Cut selection',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Cut.png"),
          :method => :cmdCut,
          :accelerator => [ Wx::MOD_CMD, 'x'[0] ]
        }
      end

      # Command that cuts an object into the clipboard
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *selection* (_MultipleSelection_): the current selection.
      def cmdCut(iParams)
        lSelection = iParams[:selection]
        lSerializedTags, lSerializedShortcuts = lSelection.getSerializedSelection
        # If there is something to copy, fill the clipboard with it.
        if ((!lSerializedShortcuts.empty?) or
            (!lSerializedTags.empty?))
          lCopyID = getNewCopyID
          lClipboardData = Tools::DataObjectSelection.new
          lClipboardData.setData(Wx::ID_CUT, lCopyID, lSerializedTags, lSerializedShortcuts)
          Wx::Clipboard.open do |ioClipboard|
            ioClipboard.data = lClipboardData
          end
          notifyObjectsCut(lSelection, lCopyID)
        end
      end

    end

  end

end
