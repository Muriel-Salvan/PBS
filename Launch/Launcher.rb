#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This file is the entry point of PBS: this is the file to call to execute PBS, regardless of the platform

module PBS

  module Launch

    class Launcher

      # 1. Setup environment (global variables)
      # 2. Check wxruby ok
      # 3. Run PBS
      #
      # Parameters:
      # * *iRootDir* (_String_): The root dir of PBS
      # * *iPlatform* (_Object_): The object containing platform dependent methods
      def launch(iRootDir, iPlatform)
        # Test if we can write to stdout
        $PBS_ScreenOutput = true
        begin
          $stdout << "Launch PBS - stdout\n"
        rescue Exception
          # Redirect to a file if possible
          begin
            lFile = File.open('./stdout', 'w')
            $stdout.reopen(lFile)
            $stdout << "Launch PBS - stdout\n"
          rescue Exception
            # Disable
            $PBS_ScreenOutput = false
          end
        end
        # Test if we can write to stderr
        $PBS_ScreenOutputErr = true
        begin
          $stderr << "Launch PBS - stderr\n"
        rescue Exception
          # Redirect to a file if possible
          begin
            lFileErr = File.open('./stderr', 'w')
            $stderr.reopen(lFileErr)
            $stderr << "Launch PBS - stderr\n"
          rescue Exception
            # Disable
            $PBS_ScreenOutputErr = false
          end
        end
        # Initialize constants
        # The platform dependent object
        $PBS_Platform = iPlatform
        # Global constants
        $PBS_Exiting = nil
        $PBS_LogFile = nil
        $PBS_DevDebug = nil
        $PBS_StartupFile = nil
        # Command line only variables
        $PBS_DisplayUsage = nil
        $PBS_UsageError = nil
        # Global paths
        # Root dir used as a based for images directories, plugins to be required...
        $PBS_RootDir = File.expand_path(iRootDir)
        $PBS_LibDir = "#{$PBS_RootDir}/lib"
        $PBS_GraphicsDir = "#{$PBS_LibDir}/Graphics"
        $PBS_ExtDir = "#{$PBS_RootDir}/ext/#{RUBY_PLATFORM}"
        $PBS_ExtGemsDir = "#{$PBS_ExtDir}/gems"
        $PBS_ExtDllsDir = "#{$PBS_ExtDir}/libs"
        # Add the main library directory to the load path, as well as libraries needed for PBS without plugins
        $LOAD_PATH.concat( [
          # Add Root dir as some environments do not have it
          $PBS_RootDir,
          $PBS_LibDir,
          "#{$PBS_RootDir}/ext/rubyzip-0.9.1/lib"
        ] )
        # Add zlib to the environment path
        $PBS_Platform.setSystemLibsPath($PBS_Platform.getSystemLibsPath + ["#{$PBS_RootDir}/ext/#{RUBY_PLATFORM}/zlib"])
        # Require tools to ensure wxRuby
        require 'Tools.rb'
        self.class.instance_eval('include Tools')
        if (ensureWxRuby)
          # Launch everything
          require 'pbs'
          PBS::run
        else
          $PBS_Platform.sendMsg('Unable to start PBS. Exiting.')
        end
      end

    end

  end

end

# We can't make any assumption about the current directory (Dir.getwd)
# Use the relative file path to know where are
lRootDir = "#{File.dirname(__FILE__)}/.."

# Require the platform info
require "#{lRootDir}/Launch/#{RUBY_PLATFORM}/PlatformInfo.rb"

# Launch everything based on the platform info
PBS::Launch::Launcher.new.launch(lRootDir, PBS::Launch::PlatformInfo.new)
