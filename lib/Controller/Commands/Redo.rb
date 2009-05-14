#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Redo

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdRedo(iCommands)
        iCommands[Wx::ID_REDO] = {
          :title => 'Redo',
          :help => 'Redo last undone action',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Redo.png"),
          :method => :cmdRedo,
          :accelerator => [ Wx::MOD_CMD, 'y'[0] ]
        }
      end

      # Command the redo last undone operation
      def cmdRedo
        # Get the last redoable operation
        lUndoableOperation = @RedoStack.pop
        notifyRedoUpdate
        # Add it to the Undo stack
        @UndoStack.push(lUndoableOperation)
        notifyUndoUpdate
        # Redo it for real
        lUndoableOperation.redo
      end

    end

  end

end