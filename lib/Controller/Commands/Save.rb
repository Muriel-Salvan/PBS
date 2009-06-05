#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Save

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdSave(iCommands)
        iCommands[Wx::ID_SAVE] = {
          :title => 'Save',
          :help => 'Save current Shortcuts',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Save.png"),
          :method => :cmdSave, # TODO
          :accelerator => [ Wx::MOD_CMD, 's'[0] ]
        }
      end

      # Command that saves the current file
      def cmdSave
        undoableOperation("Save file #{File.basename(@CurrentOpenedFileName)[0..-6]}") do
          saveData(@RootTag, @ShortcutsList, @CurrentOpenedFileName)
          # To set the flag as not modified after save
          changeCurrentFileName(@CurrentOpenedFileName)
        end
      end

    end

  end

end