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

  # Program version
  $PBS_VERSION = '0.0.1.20090430'
  # Tags linked to this version
  $PBS_VERSION_TAGS = [
    'Alpha'
  ]

  # Class for the main application
  class MainApp < Wx::App

    # Constructor
    #
    # Parameters:
    # * *iController* (_Controller_): The controller of the model
    def initialize(iController)
      super()
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
      lMainFrame.show()
    end

  end

  # Get command line parameters
  #
  # Return:
  # * _OptionParser_: The options parser
  def self.getOptions
    rOptions = OptionParser.new

    rOptions.banner = 'pbs.rb [-d|--devdebug] [-l|--log <Logfile>]'
    rOptions.on('-d', '--devdebug',
      'Set developer debug interface.') do
      $PBS_DevDebug = true
    end
    rOptions.on('-l', '--log <Logfile>', String,
      '<Logfile>: Name of a file to log into.',
      'Set log file.') do |iArg|
      $PBS_LogFile = iArg
    end

    return rOptions
  end

  # Run PBS
  def self.run
    # Default variables, that can be altered with command line options
    $PBS_DevDebug = false
    $PBS_LogFile = nil
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
