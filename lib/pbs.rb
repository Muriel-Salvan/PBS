#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rubygems'
require 'wx'

# Add this path to the load path. This allows anybody to execute PBS from any directory, even not the current one.
$LOAD_PATH << File.dirname(__FILE__)

require 'Controller/Controller.rb'
require 'Windows/Main.rb'

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

end

# Be prepared to be just a library: don't do anything unless called explicitly
if (__FILE__ == $0)
  PBS::MainApp.new(PBS::Controller.new).main_loop
end
