#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Exit

      # Constructor
      def initialize
        @ExitProcess = false
      end

      # Command that exits PBS
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Protect this method from concurrent executions (exiting Windows calls evt_close twice, user could click several times on close...)
        if (!@ExitProcess)
          @ExitProcess = true
          lTryExit = true
          while (lTryExit)
            if (ioController.checkSavedWork(lWindow))
              # Make sure we are error prone
              begin
                ioController.notifyExit
              rescue Exception
                logExc $!, 'An error has occurred while exiting.'
              end
              lTryExit = false
            else
              # If no integration plugin is to be instantiated, bring the Options dialog
              lIntPluginActive = ioController.isIntPluginActive?
              if (!lIntPluginActive)
                logMsg 'All views have been disabled or closed. Please activate some integration plugins to use to display PBS.'
                # Bring the Options dialog
                ioController.executeCommand(Wx::ID_SETUP, :parentWindow => lWindow)
                # Check again
                lTryExit = (!ioController.isIntPluginActive?)
              else
                lTryExit = false
              end
              # Consider we are not anymore in the exit process only if we chose to not exit anymore
              @ExitProcess = lTryExit
            end
          end
        end
      end

    end

  end

end
