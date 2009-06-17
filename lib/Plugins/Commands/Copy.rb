#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Copy

      include Tools

      # Give the description of this plugin
      #
      # Return:
      # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
      # ** :title (_String_): Name of the plugin
      # ** :description (_String_): Quick description
      # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
      # # Specific parameters to Command plugins:
      # ** :commandID (_Integer_): The command ID
      # ** :accelerator (<em>[Integer,Integer]</em>): The accelerator (modifier and key)
      # ** :parameters (<em>list<Symbol></em>): The list of symbols that GUIs have to provide to the execute method
      def pluginInfo
        return {
          :title => 'Copy',
          :description => 'Copy selection',
          :bitmapName => 'Copy.png',
          :commandID => Wx::ID_COPY,
          :accelerator => [ Wx::MOD_CMD, 'c'[0] ],
          :parameters => [
            :selection
          ]
        }
      end

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
