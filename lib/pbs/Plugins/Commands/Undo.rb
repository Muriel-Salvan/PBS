#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Undo

      # Undo last operation
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
