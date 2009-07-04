#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This file has to be required with wxruby already part of the environment
# This is made on purpose, as depending on the way the pplication is launch, wxruby may be statically compiled in the executable that invoked pbs.rb, and in this case there is no require authorized.

require 'optparse'

# Disabling the Garbage Collector prevents several main WxRuby bugs:
# * The Drag'n'Drop from the main tree does not cause SegFaults anymore.
# * Destroying Windows manually does not cause SegFaults anymore during random events.
# * Not destroying Windows manually does not cause ObjectPreviouslyDeleted exceptions on exit.
# However, disabling GC does increase memory consumption of around 30Mb every 5 minutes of usage.
GC.disable

module PBS

  # Class for the main application
  class MainApp < Wx::App

    include Tools

    # Constructor
    #
    # Parameters:
    # * *iController* (_Controller_): The controller of the model
    def initialize(iController)
      super()
      logInfo "Starting PBS #{$PBS_VERSION}"
      @Controller = iController
    end

    # Initialize the application
    def on_init
      lMainFrame = MainFrame.new(nil, @Controller)
      @Controller.init
      lMainFrame.init
      # Register all windows that will receive notifications
      # The main one
      @Controller.registerGUI(lMainFrame)
      # Each integration plugin
      @Controller.registerIntegrationPluginsGUIs
      # Begin
      @Controller.notifyInit
      # Load the startup file if needed
      if ($PBS_StartupFile != nil)
        if (File.exists?($PBS_StartupFile))
          @Controller.undoableOperation("Load initial file #{File.basename($PBS_StartupFile)[0..-6]}") do
            openData(@Controller, $PBS_StartupFile)
            @Controller.changeCurrentFileName($PBS_StartupFile)
          end
        else
          logErr "Unable to find file \"#{$PBS_StartupFile}\""
        end
      end

      lMainFrame.show()
    end

  end

  # Get command line parameters
  #
  # Return:
  # * _OptionParser_: The options parser
  def self.getOptions
    rOptions = OptionParser.new

    rOptions.banner = 'pbs.rb [-d|--devdebug] [-l|--log <Logfile>] [-f|--file <PBSFile>]'
    rOptions.on('-d', '--devdebug',
      'Set developer debug interface.') do
      $PBS_DevDebug = true
    end
    rOptions.on('-l', '--log <Logfile>', String,
      '<Logfile>: Name of a file to log into.',
      'Set log file.') do |iArg|
      $PBS_LogFile = iArg
    end
    rOptions.on('-f', '--file <PBSFile>', String,
      '<PBSFile>: Name of a file to load first.',
      'Give a file to load just after starting PBS.') do |iArg|
      $PBS_StartupFile = iArg
    end

    return rOptions
  end

  # Run PBS
  def self.run
    # Parse command line arguments
    lOptions = self.getOptions
    lSuccess = true
    begin
      lOptions.parse(ARGV)
    rescue Exception
      puts "Error while parsing arguments: #{$!}"
      puts lOptions
      lSuccess = false
    end
    if (lSuccess)
      MainApp.new(PBS::Controller.new).main_loop
    end
  end

end

# Require those files after having defined global $PBS_* variables, as it will be used during require
require 'pbsversion.rb'
# Common utilities
require 'Tools.rb'
require 'DataObject.rb'
# The model
require 'Model/Common.rb'
require 'Model/Tag.rb'
require 'Model/Shortcut.rb'
require 'Model/MultipleSelection.rb'
require 'Model/MissingDependencies.rb'
# The controller
require 'Controller/Controller.rb'
# The view
require 'Windows/Main.rb'

# Be prepared to be just a library: don't do anything unless called explicitly
if (__FILE__ == $0)
  PBS::run
end
