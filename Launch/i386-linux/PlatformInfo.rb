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
        return OS_LINUX
      end

      # Return the list of directories where we look for libraries
      #
      # Return:
      # * <em>list<String></em>: List of directories
      def getSystemLibsPath
        rList = ENV['PATH'].split(':')

        if (ENV['LD_LIBRARY_PATH'] != nil)
          rList += ENV['LD_LIBRARY_PATH'].split(':')
        end
        
        return rList
      end

      # Set the list of directories where we look for libraries
      #
      # Parameters:
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemLibsPath(iNewDirsList)
        ENV['LD_LIBRARY_PATH'] = iNewDirsList.join(':')
      end

      # This method sends a message (platform dependent) to the user, without the use of wxruby
      #
      # Parameters:
      # * *iMsg* (_String_): The message to display
      def sendMsg(iMsg)
        # TODO: Handle case of xmessage not installed
        system("xmessage \"#{iMsg}\"")
      end

      # Execute a Shell command.
      # Do not wait for its termination.
      #
      # Parameters:
      # * *iCmd* (_String_): The command to execute
      # * *iInTerminal* (_Boolean_): Do we execute this command in a separate terminal ?
      # Return:
      # * _Exception_: Error, or nil if success
      def execShellCmdNoWait(iCmd, iInTerminal)
        rException = nil

        if (iInTerminal)
          # TODO: Handle case of xterm not installed
          if (!system("xterm -e \"#{iCmd}\""))
            rException = RuntimeError.new
          end
        else
          begin
            IO.popen(iCmd)
          rescue Exception
            rException = $!
          end
        end

        return rException
      end

      # Execute a given URL to be launched in a browser
      #
      # Parameters:
      # * *iURL* (_String_): The URL to launch
      # Return:
      # * _String_: Error message, or nil if success
      def launchURL(iURL)
        rError = nil

        begin
          IO.popen("xdg-open '#{iURL}'")
        rescue Exception
          rError = $!.to_s
        end

        return rError
      end

      # Get file extensions specifics to executable files
      #
      # Return:
      # * <em>list<String></em>: List of extensions (including . character). It can be empty.
      def getExecutableExtensions
        return []
      end

    end

  end

end
