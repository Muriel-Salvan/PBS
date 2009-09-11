#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This file has to be required with wxruby already part of the environment
# This is made on purpose, as depending on the way the application is launched, wxruby may be statically compiled in the executable that invoked pbs.rb, and in this case there is no require authorized.

# Disabling the Garbage Collector prevents several main WxRuby bugs:
# * The Drag'n'Drop from the main tree does not cause SegFaults anymore.
# * Destroying Windows manually does not cause SegFaults anymore during random events.
# * Not destroying Windows manually does not cause ObjectPreviouslyDeleted exceptions on exit.
# However, disabling GC does increase memory consumption of around 30Mb every 5 minutes of usage.
GC.disable

require 'rUtilAnts/Platform'
RUtilAnts::Platform.initializePlatform
require 'rUtilAnts/Misc'
RUtilAnts::Misc.initializeMisc
require 'rUtilAnts/GUI'
RUtilAnts::GUI.initializeGUI
require 'rUtilAnts/URLAccess'
RUtilAnts::URLAccess.initializeURLAccess
require 'rUtilAnts/URLCache'
RUtilAnts::URLCache.initializeURLCache
require 'rUtilAnts/Plugins'
RUtilAnts::Plugins.initializePlugins

require 'pbsversion.rb'
# Common utilities
require 'pbs/Common/Tools.rb'
# Do this to avoid having to "include Tools" in every class.
Object.module_eval('include PBS::Tools')
require 'pbs/DataObject.rb'
# The model
require 'pbs/Model/Common.rb'
require 'pbs/Model/Tag.rb'
require 'pbs/Model/Shortcut.rb'
require 'pbs/Model/MultipleSelection.rb'
require 'pbs/Model/MissingDependencies.rb'
# The controller
require 'pbs/Controller/Controller.rb'
# The main view
require 'pbs/Windows/Main.rb'

module PBS

  # Class for the main application
  class MainApp < Wx::App

    # Constructor
    #
    # Parameters:
    # * *iPBSRootDir* (_String_): PBS root dir
    # * *iDebugOption* (_Boolean_): Is debug on ?
    # * *iStartupFileNames* (<em>list<String></em>): List of files to load at startup
    def initialize(iPBSRootDir, iDebugOption, iStartupFileNames)
      logInfo "Starting PBS #{$PBS_VERSION}"
      super()
      @StartupFileNames = iStartupFileNames
      # Global constants
      $PBS_Exiting = nil
      $PBS_DevDebug = iDebugOption
      # Global paths
      # Root dir used as a base for images directories, plugins to be required...
      $PBS_GraphicsDir = "#{iPBSRootDir}/lib/pbs/Graphics"
      @Controller = PBS::Controller.new(iPBSRootDir)
    end

    # Initialize the application
    def on_init
      lMainFrame = MainFrame.new(nil, @Controller)
      @Controller.init
      lMainFrame.init
      # Register all windows that will receive notifications
      # The main one
      @Controller.registerGUI(lMainFrame)
      # Load the startup file if needed
      if (!@StartupFileNames.empty?)
        lFirstOne = true
        @StartupFileNames.each do |iFileName|
          if (File.exists?(iFileName))
            @Controller.undoableOperation("Load startup file #{File.basename(iFileName)[0..-6]}") do
              # Open and merge
              openData(@Controller, iFileName)
              if (lFirstOne)
                @Controller.changeCurrentFileName(iFileName)
              end
              lFirstOne = false
            end
          else
            logErr "Unable to find file \"#{iFileName}\""
          end
        end
      end
      # Begin
      @Controller.notifyInit
      # Notify everybody that options have been changed to initialize them
      @Controller.notifyOptionsChanged({})

      # If we ask for startup tips, go on !
      if (@Controller.Options[:displayStartupTips])
        @Controller.showTips(lMainFrame)
      end

      lMainFrame.show
      
      return true
    end

  end

end
