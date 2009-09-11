#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Redo

      # Redo last undone operation
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