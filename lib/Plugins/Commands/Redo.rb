#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Redo

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
          :title => 'Redo',
          :description => 'Redo last undone action',
          :bitmapName => 'Redo.png',
          :commandID => Wx::ID_REDO,
          :accelerator => [ Wx::MOD_CMD, 'y'[0] ],
          :parameters => []
        }
      end

      # Command the redo last undone operation
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        # Get the last redoable operation
        lUndoableOperation = ioController.RedoStack.pop
        ioController.notifyRedoUpdate
        # Add it to the Undo stack
        ioController.UndoStack.push(lUndoableOperation)
        ioController.notifyUndoUpdate
        # Redo it for real
        lUndoableOperation.redo
      end

    end

  end

end