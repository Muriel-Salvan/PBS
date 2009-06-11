#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Copy

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdCopy(iCommands)
        iCommands[Wx::ID_COPY] = {
          :title => 'Copy',
          :help => 'Copy selection',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Copy.png"),
          :method => :cmdCopy,
          :accelerator => [ Wx::MOD_CMD, 'c'[0] ]
        }
      end

      # Command that copies an object into the clipboard
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *selection* (_MultipleSelection_): the current selection.
      def cmdCopy(iParams)
        lSelection = iParams[:selection]
        lSerializedSelection = lSelection.getSerializedSelection
        # If there is something to copy, fill the clipboard with it.
        if (!lSerializedSelection.empty?)
          lCopyID = getNewCopyID
          lClipboardData = Tools::DataObjectSelection.new
          lClipboardData.setData(Wx::ID_COPY, lCopyID, lSerializedSelection)
          Wx::Clipboard.open do |ioClipboard|
            ioClipboard.data = lClipboardData
          end
          notifyObjectsCopied(lSelection, lCopyID)
        end
      end

    end

  end

end
