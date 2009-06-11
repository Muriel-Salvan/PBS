#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Open

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdOpen(iCommands)
        iCommands[Wx::ID_OPEN] = {
          :title => 'Open',
          :help => 'Open a PBS file',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Open.png"),
          :method => :cmdOpen,
          :accelerator => [ Wx::MOD_CMD, 'o'[0] ]
        }
      end

      # Command that opens a file
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdOpen(iParams)
        lWindow = iParams[:parentWindow]
        # Display Open dialog
        showModal(Wx::FileDialog, lWindow,
          :message => 'Open file',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            if (checkSavedWorkAndScratch(lWindow))
              undoableOperation("Open file #{File.basename(iDialog.path)[0..-6]}") do
                # Really perform the open
                openData(self, iDialog.path)
                changeCurrentFileName(iDialog.path)
              end
            end
          end
        end
      end

    end

  end

end
