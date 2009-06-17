#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Undo

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
          :title => 'Undo',
          :description => 'Undo last action',
          :bitmapName => 'Undo.png',
          :commandID => Wx::ID_UNDO,
          :accelerator => [ Wx::MOD_CMD, 'z'[0] ],
          :parameters => []
        }
      end

      # Command that undo last operation
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        # Get the last undoable operation
        lUndoableOperation = ioController.UndoStack.pop
        ioController.notifyUndoUpdate
        # Add it to the Redo stack
        ioController.RedoStack.push(lUndoableOperation)
        ioController.notifyRedoUpdate
        # Undo it for real
        lUndoableOperation.undo
      end

    end

  end

end
