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

require 'pbsversion'
# Common utilities
require 'pbs/Common/Tools'
# Do this to avoid having to "include Tools" in every class.
Object.module_eval('include PBS::Tools')
require 'pbs/DataObject'
# The model
require 'pbs/Model/Common'
require 'pbs/Model/Tag'
require 'pbs/Model/Shortcut'
require 'pbs/Model/MultipleSelection'
# The controller
require 'pbs/Controller/Controller'

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
      @PBSRootDir, @StartupFileNames = iPBSRootDir, iStartupFileNames
      # Global constants
      $PBS_DevDebug = iDebugOption
      # Global paths
      # Root dir used as a base for images directories, plugins to be required...
      $PBS_GraphicsDir = "#{iPBSRootDir}/lib/pbs/Graphics"
    end

    # Initialize the application
    def on_init
      # Create the Controller
      lController = PBS::Controller.new(@PBSRootDir)
      # Load the startup file if needed
      if (!@StartupFileNames.empty?)
        lFirstOne = true
        @StartupFileNames.each do |iFileName|
          if (File.exists?(iFileName))
            lController.undoableOperation("Load startup file #{File.basename(iFileName)[0..-6]}") do
              # Open and merge
              openData(lController, iFileName)
              if (lFirstOne)
                lController.changeCurrentFileName(iFileName)
              end
              lFirstOne = false
            end
          else
            logErr "Unable to find file \"#{iFileName}\""
          end
        end
      end
      # Begin
      lController.notifyInit
      # Notify everybody that options have been changed to initialize them
      # This step creates all integration plugin instances
      lController.notifyOptionsChanged({})

      # If no integration plugin is to be instantiated, bring the Options dialog
      lIntPluginActive = lController.isIntPluginActive?
      if (!lIntPluginActive)
        logMsg 'All views have been disabled or closed. Please activate some integration plugins to use to display PBS.'
        # Bring the Options dialog
        lController.executeCommand(Wx::ID_SETUP, :parentWindow => nil)
        # Check again
        lIntPluginActive = lController.isIntPluginActive?
      end

      # If we ask for startup tips, go on !
      if (lController.Options[:displayStartupTips])
        lTopWindow = top_window
        if (lTopWindow == nil)
          logErr 'No window available for tips display. Please specify at least 1 integration plugin to be used, or delete the current Options file.'
        else
          lController.showTips(lTopWindow)
        end
      end

      return lIntPluginActive
    end

  end

end
