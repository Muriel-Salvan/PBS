#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Launch

    class PlatformInfo

      # Return the ID of the OS
      # This is then used for PBS and plugins to adapt their behaviour
      #
      # Return:
      # * _Integer_: OS ID
      def os
        return OS_WINDOWS
      end

      # Return the list of directories where we look for libraries
      #
      # Return:
      # * <em>list<String></em>: List of directories
      def getSystemLibsPath
        return ENV['PATH'].split(';')
      end

      # Set the list of directories where we look for libraries
      #
      # Parameters:
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemLibsPath(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(';')
      end

      # This method sends a message (platform dependent) to the user, without the use of wxruby
      #
      # Parameters:
      # * *iMsg* (_String_): The message to display
      def sendMsg(iMsg)
        # !!! iMsg must not be longer than 256 characters
        if (iMsg.size > 256)
          system("msg \"#{ENV['USERNAME']}\" /W #{iMsg[0..255]}")
        else
          system("msg \"#{ENV['USERNAME']}\" /W #{iMsg}")
        end
      end

    end

  end

end
