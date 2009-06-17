#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Cut

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
          :title => 'Cut',
          :description => 'Cut selection',
          :bitmapName => 'Cut.png',
          :commandID => Wx::ID_CUT,
          :accelerator => [ Wx::MOD_CMD, 'x'[0] ],
          :parameters => [
            :selection
          ]
        }
      end

      # Command that cuts an object into the clipboard
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
          lClipboardData.setData(Wx::ID_CUT, lCopyID, lSerializedSelection)
          Wx::Clipboard.open do |ioClipboard|
            ioClipboard.data = lClipboardData
          end
          ioController.notifyObjectsCut(lSelection, lCopyID)
        end
      end

    end

  end

end
