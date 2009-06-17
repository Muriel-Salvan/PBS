#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Save

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
          :title => 'Save',
          :description => 'Save current Shortcuts',
          :bitmapName => 'Save.png',
          :commandID => Wx::ID_SAVE,
          :accelerator => [ Wx::MOD_CMD, 's'[0] ],
          :parameters => []
        }
      end

      # Command that saves the current file
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        ioController.undoableOperation("Save file #{File.basename(ioController.CurrentOpenedFileName)[0..-6]}") do
          saveData(ioController, ioController.CurrentOpenedFileName)
          # To set the flag as not modified after save
          ioController.changeCurrentFileName(ioController.CurrentOpenedFileName)
        end
      end

    end

  end

end