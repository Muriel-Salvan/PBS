#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Tips

      # Command that edits an item (Shortcut/Tag).
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      #   * *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        ioController.showTips(lWindow)
      end

    end

  end

end
