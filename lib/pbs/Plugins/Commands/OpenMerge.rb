#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class OpenMerge

      # Command that opens a file and merges its content with the current project
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Display Open dialog
        showModal(Wx::FileDialog, lWindow,
          :message => 'Open file for merge',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            ioController.undoableOperation("Merge file #{File.basename(iDialog.path)[0..-6]}") do
              # Really perform the open
              openData(ioController, iDialog.path)
            end
          end
        end
      end

    end

  end

end