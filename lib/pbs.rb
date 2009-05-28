#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'optparse'
require 'rubygems'
require 'wx'

# Add this path to the load path. This allows anybody to execute PBS from any directory, even not the current one.
$LOAD_PATH << File.dirname(__FILE__)

module PBS

  # Program version
  $PBS_VERSION = '0.0.1.20090430'

  # Root dir used as a based for images directories, plugins to be required...
  $PBSRootDir = File.dirname(__FILE__)

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

    rOptions.banner = 'pbs.rb [-d|--devdebug]'
    rOptions.on('-d', '--devdebug',
      'Set developer debug interface.') do
      $PBS_DevDebug = true
    end

    return rOptions
  end

end

# Require those files after having defined $PBSRootDir, as it will be used during require
require 'Controller/Controller.rb'
require 'Windows/Main.rb'

# Be prepared to be just a library: don't do anything unless called explicitly
if (__FILE__ == $0)
  # Default switches, that can be altered with command line options
  $PBS_DevDebug = false
  # Parse command line arguments
  lOptions = PBS::getOptions
  lSuccess = true
  begin
    lOptions.parse(ARGV)
  rescue Exception
    puts "Error while parsing arguments: #{$!}"
    puts lOptions
    lSuccess = false
  end
  if (lSuccess)
    PBS::MainApp.new(PBS::Controller.new).main_loop
  end
end
