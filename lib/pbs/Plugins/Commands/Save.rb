#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Save

      # Command that saves the current file
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        ioController.undoableOperation("Save file #{File.basename(ioController.CurrentOpenedFileName)[0..-6]}") do
          saveData(ioController, ioController.CurrentOpenedFileName)
          # To set the flag as not modified after save
          ioController.changeCurrentFileName(ioController.CurrentOpenedFileName)
        end
      end

    end

  end

end