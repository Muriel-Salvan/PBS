#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module SaveAs

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdSaveAs(iCommands)
        iCommands[Wx::ID_SAVEAS] = {
          :title => 'Save As',
          :help => 'Save current Shortcuts in a new PBS file',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/SaveAs.png"),
          :method => :cmdSaveAs,
          :accelerator => nil
        }
      end

      # Command that saves the file in a new name
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdSaveAs(iParams)
        lWindow = iParams[:parentWindow]
        # Display Save dialog
        lSaveDialog = Wx::FileDialog.new(lWindow,
          :message => 'Save file',
          :style => Wx::FD_SAVE|Wx::FD_OVERWRITE_PROMPT,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        )
        case lSaveDialog.show_modal
        when Wx::ID_OK
          undoableOperation("Save file #{File.basename(lSaveDialog.path)[0..-6]}") do
            # Perform save
            saveData(self, lSaveDialog.path)
            changeCurrentFileName(lSaveDialog.path)
          end
        end
      end

    end

  end

end
