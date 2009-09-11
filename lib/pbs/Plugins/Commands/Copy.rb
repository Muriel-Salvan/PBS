#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Copy

      # Command that copies an object into the clipboard
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *selection* (_MultipleSelection_): the current selection.
      def execute(ioController, iParams)
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
          ioController.notifyObjectsCopied(lSelection, lCopyID)
        end
      end

    end

  end

end
