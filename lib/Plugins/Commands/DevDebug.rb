#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class DevDebug

      include Tools

      # Give the description of this plugin
      #
      # Return:
      # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
      # ** :title (_String_): Name of the plugin
      # ** :description (_String_): Quick description
      # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
      # # Specific parameters to Command plugins:
      # ** :commandID (_Integer_): The command ID
      # ** :accelerator (<em>[Integer,Integer]</em>): The accelerator (modifier and key)
      # ** :parameters (<em>list<Symbol></em>): The list of symbols that GUIs have to provide to the execute method
      def pluginInfo
        return {
          :title => 'Debug',
          :description => 'Dump some useful debugging information, relevant for developers only',
          :bitmapName => 'DevDebug.png',
          :commandID => ID_DEVDEBUG,
          :parameters => []
        }
      end

      # Command that copies an object into the clipboard
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        puts "=== Tags:"
        dumpTag(ioController.RootTag)
        puts "=== Shortcuts:"
        dumpShortcutsList(ioController.ShortcutsList)
        ioController.notifyRegisteredGUIs(:onDevDebug)
      end

    end

  end

end
