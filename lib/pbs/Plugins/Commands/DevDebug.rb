#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class DevDebug

      # Command that copies an object into the clipboard
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        logDebug '=== Tags:'
        logDebug dumpTag(ioController.RootTag)
        logDebug '=== Shortcuts:'
        logDebug dumpShortcutsList(ioController.ShortcutsList)
        logDebug '=== $LOAD_PATH:'
        logDebug $LOAD_PATH.join("\n")
        if (defined?(Gem) != nil)
          logDebug '=== Gem.path:'
          logDebug Gem.path.join("\n")
        else
          logDebug 'Gem not defined.'
        end
        ioController.dumpDebugInfo
        ioController.notifyRegisteredGUIs(:onDevDebug)
      end

    end

  end

end
