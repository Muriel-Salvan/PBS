#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This file has to be required with wxruby already part of the environment
# This is made on purpose, as depending on the way the application is launched, wxruby may be statically compiled in the executable that invoked pbs.rb, and in this case there is no require authorized.

# Disabling the Garbage Collector prevents several main WxRuby bugs:
# * The Drag'n'Drop from the main tree does not cause SegFaults anymore [ Corrected in wxRuby 2.0.1 ].
# * Destroying Windows manually does not cause SegFaults anymore during random events.
# * Not destroying Windows manually does not cause ObjectPreviouslyDeleted exceptions on exit.
# * Random crashes when invoking a menu from the tray icon [ Partly corrected in wxRuby 2.0.2 ].
# However, disabling GC does increase memory consumption of around 30Mb every 5 minutes of usage.
#GC.disable

require 'rUtilAnts/Platform'
RUtilAnts::Platform.install_platform_on_object
require 'rUtilAnts/Misc'
RUtilAnts::Misc.install_misc_on_object
require 'rUtilAnts/GUI'
RUtilAnts::GUI.initializeGUI
require 'rUtilAnts/URLAccess'
RUtilAnts::URLAccess.install_url_access_on_object
require 'rUtilAnts/URLCache'
RUtilAnts::URLCache.install_url_cache_on_object
require 'rUtilAnts/Plugins'
RUtilAnts::Plugins.install_plugins_on_object

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
    # Parameters::
    # * *iPBSRootDir* (_String_): PBS root dir
    # * *iDebugOption* (_Boolean_): Is debug on ?
    # * *iStartupFileNames* (<em>list<String></em>): List of files to load at startup
    def initialize(iPBSRootDir, iDebugOption, iStartupFileNames)
      # Read version info
      $PBS_ReleaseInfo = {
        :Version => 'Development',
        :Tags => [],
        :DevStatus => 'Unofficial'
      }
      lReleaseInfoFileName = "#{iPBSRootDir}/ReleaseInfo"
      if (File.exists?(lReleaseInfoFileName))
        File.open(lReleaseInfoFileName, 'r') do |iFile|
          $PBS_ReleaseInfo = eval(iFile.read)
        end
      end
      log_info "Starting PBS #{$PBS_ReleaseInfo[:Version]}"
      super()
      @PBSRootDir, @StartupFileNames = iPBSRootDir, iStartupFileNames
      # Global constants
      $PBS_DevDebug = iDebugOption
      # Global paths
      # Root dir used as a base for images directories, plugins to be required...
      $PBS_GraphicsDir = "#{iPBSRootDir}/lib/pbs/Graphics"
    end

    # Initialize the application
    #
    # Return::
    # * _Boolean_: Do we enter the event loop ?
    def on_init
      rEnterEventLoop = false

      set_gui_for_dialogs(RUtilAnts::Logging::GUI_WX)
      # Protect it to display correct error messages
      begin
        # We can set a progress dialog, do it now: the user has already waited too long !!!
        setupBitmapProgress(nil, getGraphic('Splash.png'),
          :title => "Launching PBS #{$PBS_ReleaseInfo[:Version]}",
          :icon => getGraphic('Icon32.png')
        ) do |ioProgressDlg|
          ioProgressDlg.set_range(6)
          # If we are in debug mode, make the GC clean memory every second.
          # It will help finding bugs that are memory related.
          if ($PBS_DevDebug)
            Wx.get_app.gc_stress
          end
          # Create the Controller
          lController = PBS::Controller.new(@PBSRootDir)
          ioProgressDlg.inc_value
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
                log_err "Unable to find file \"#{iFileName}\""
              end
            end
          end
          ioProgressDlg.inc_value
          # Begin
          lController.notifyInit
          ioProgressDlg.inc_value
          # Notify everybody that options have been changed to initialize them
          # This step creates all integration plugin instances
          lController.notifyOptionsChanged({})
          ioProgressDlg.inc_value

          # If no integration plugin is to be instantiated, bring the Options dialog
          lIntPluginActive = lController.isIntPluginActive?
          if (!lIntPluginActive)
            log_msg 'All views have been disabled or closed. Please activate some integration plugins to use to display PBS.'
            # Bring the Options dialog
            lController.executeCommand(Wx::ID_SETUP, :parentWindow => nil)
            # Check again
            lIntPluginActive = lController.isIntPluginActive?
          end
          ioProgressDlg.inc_value

          # If we ask for startup tips, go on !
          if (lController.Options[:displayStartupTips])
            lTopWindow = top_window
            if (lTopWindow == nil)
              log_err 'No window available for tips display. Please specify at least 1 integration plugin to be used, or delete the current Options file.'
            else
              lController.showTips(lTopWindow)
            end
          end
          ioProgressDlg.inc_value
          rEnterEventLoop = lIntPluginActive
        end
      rescue Exception
        log_exc $!, 'Exception occurred during startup. Quitting.'
        rEnterEventLoop = false
      end

      return rEnterEventLoop
    end

  end

end
