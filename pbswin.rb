#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  class Platform_mswin32

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
      system("msg \"#{ENV['USERNAME']}\" /W #{iMsg}")
    end

  end

end

require 'launcher.rb'
PBS::Launcher.new.launch(File.dirname(__FILE__), PBS::Platform_mswin32.new)
