#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class DevDebug

      # Command that copies an object into the clipboard
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        log_debug '=== Tags:'
        log_debug dumpTag(ioController.RootTag)
        log_debug '=== Shortcuts:'
        log_debug dumpShortcutsList(ioController.ShortcutsList)
        log_debug '=== $LOAD_PATH:'
        log_debug $LOAD_PATH.join("\n")
        if (defined?(Gem) != nil)
          log_debug '=== Gem.path:'
          log_debug Gem.path.join("\n")
        else
          log_debug 'Gem not defined.'
        end
        ioController.dumpDebugInfo
        ioController.notifyRegisteredGUIs(:onDevDebug)
      end

    end

  end

end
