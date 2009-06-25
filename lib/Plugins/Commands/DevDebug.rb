#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class DevDebug

      include Tools

      # Command that copies an object into the clipboard
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        logDebug "=== Tags:"
        logDebug dumpTag(ioController.RootTag)
        logDebug "=== Shortcuts:"
        logDebug dumpShortcutsList(ioController.ShortcutsList)
        ioController.notifyRegisteredGUIs(:onDevDebug)
      end

    end

  end

end
