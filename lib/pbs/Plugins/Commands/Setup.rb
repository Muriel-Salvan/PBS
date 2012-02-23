#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Setup

      # Command that launches the setup
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      #   * *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Display Options dialog
        require 'pbs/Windows/OptionsDialog'
        showModal(OptionsDialog, lWindow, ioController.Options, ioController) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            lOldOptions = ioController.Options.clone
            # Set options of the dialog
            iDialog.getOptions.each do |iKey, iValue|
              ioController.Options[iKey] = iValue
            end
            ioController.notifyOptionsChanged(lOldOptions)
          end
        end
      end

    end

  end

end
