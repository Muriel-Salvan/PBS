#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module DevDebug

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdDevDebug(iCommands)
        iCommands[ID_DEVDEBUG] = {
          :title => 'Debug',
          :help => 'Dump some useful debugging information, relevant for developers only',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/DevDebug.png"),
          :method => :cmdDevDebug,
          :accelerator => nil
        }
      end

      # Command that copies an object into the clipboard
      def cmdDevDebug
        puts "=== Tags:"
        dumpTag(@RootTag)
        puts "=== Shortcuts:"
        dumpShortcutsList(@ShortcutsList)
        notifyRegisteredGUIs(:onDevDebug)
      end

    end

  end

end
