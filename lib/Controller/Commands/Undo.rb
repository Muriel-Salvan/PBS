#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Undo

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdUndo(iCommands)
        iCommands[Wx::ID_UNDO] = {
          :title => 'Undo',
          :help => 'Undo last action',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Undo.png"),
          :method => :cmdUndo,
          :accelerator => [ Wx::MOD_CMD, 'z'[0] ]
        }
      end

      # Command that undo last operation
      def cmdUndo
        # Get the last undoable operation
        lUndoableOperation = @UndoStack.pop
        notifyUndoUpdate
        # Add it to the Redo stack
        @RedoStack.push(lUndoableOperation)
        notifyRedoUpdate
        # Undo it for real
        lUndoableOperation.undo
      end

    end

  end

end
