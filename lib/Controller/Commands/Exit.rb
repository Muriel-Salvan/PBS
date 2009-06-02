#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Exit

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdExit(iCommands)
        iCommands[Wx::ID_EXIT] = {
          :title => 'Exit',
          :help => 'Quit PBS',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Exit.png"),
          :method => :cmdExit,
          :accelerator => nil
        }
      end

      # Command that saves the file in a new name
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdExit(iParams)
        lWindow = iParams[:parentWindow]
        if (checkSavedWork(lWindow))
          notifyExit
        end
      end

    end

  end

end
