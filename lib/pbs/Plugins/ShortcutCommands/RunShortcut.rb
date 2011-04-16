#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module ShortcutCommands

    class RunShortcut

      # Command that gives a default icon to a Shortcut
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *ioShortcut* (_Shortcut_): The Shortcut for which we called this command
      def execute(ioController, ioShortcut)
        ioShortcut.run
      end

    end

  end

end
