#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class SaveAs

      # Command that saves the file in a new name
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      #   * *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Display Save dialog
        showModal(Wx::FileDialog, lWindow,
          :message => 'Save file',
          :style => Wx::FD_SAVE|Wx::FD_OVERWRITE_PROMPT,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            ioController.undoableOperation("Save file #{File.basename(iDialog.path)[0..-6]}") do
              # Perform save
              saveData(ioController, iDialog.path)
              ioController.changeCurrentFileName(iDialog.path)
            end
          end
        end
      end

    end

  end

end
