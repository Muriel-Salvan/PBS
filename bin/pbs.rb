#!/bin/env ruby
#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This file is the entry point of PBS: this is the file to call to execute PBS, regardless of the platform

require 'optparse'

module PBS

  class Launcher

    # 1. Setup environment (global variables)
    # 2. Check wxruby ok
    # 3. Run PBS
    #
    # Parameters::
    # * *iPBSRootDir* (_String_): The root dir of PBS
    def launch(iPBSRootDir)
      # Parse command line arguments
      @DisplayUsage = false
      @DebugOption = false
      @LogFile = nil
      @UsageError = nil
      lOpenFileNames = []
      lOptions = getOptions
      begin
        lOpenFileNames = lOptions.parse(ARGV)
      rescue Exception
        @UsageError = $!
      end
      # Initialize logging
      $LOAD_PATH << "#{iPBSRootDir}/ext/rUtilAnts/lib"
      require 'rUtilAnts/Logging'
      RUtilAnts::Logging::install_logger_on_object(
        :lib_root_dir => iPBSRootDir,
        :bug_tracker_url => 'https://sourceforge.net/tracker/?group_id=261341&atid=1141657',
        :debug_mode => @DebugOption,
        :log_file => @LogFile
      )
      lExit = false
      if (@DisplayUsage)
        log_msg "Usage:\n#{lOptions}"
        lExit = true
      end
      if (@UsageError != nil)
        log_err "Error while parsing command line arguments: #{@UsageError}.\n\nUsage:\n#{lOptions}."
        lExit = true
      end
      if (!lExit)
        # Initialize constants
        # Add the main library directory to the load path, as well as libraries needed for PBS without plugins
        $LOAD_PATH.concat( [
          "#{iPBSRootDir}/lib",
          "#{iPBSRootDir}/ext/RDI/lib"
        ] )
        # The installer that will be used for dependencies
        require 'rdi/rdi'
        # Ensure wxRuby is installed, and propose it to be in a local repository if needed
        lInstaller = RDI::Installer.new(iPBSRootDir)
        lInstaller.set_default_options( {
          :preferred_views => [ 'SimpleWxGUI', 'Text' ],
          :preferred_progress_views => [ 'SimpleWxGUI', 'Text' ]
        } )
        # Get the local installation directory for Gems
        lLocalGemsDir = lInstaller.get_default_install_location('Gem', RDI::DEST_LOCAL)
        lError, lCMApplied, lIgnored, lUnresolved = lInstaller.ensure_dependencies(
          [
            RDI::Model::DependencyDescription.new('WxRuby').add_description( {
              :Testers => [
                {
                  :Type => 'RubyRequires',
                  :Content => [ 'wx' ]
                }
              ],
              :Installers => [
                {
                  :Type => 'Gem',
                  :Content => 'wxruby',
                  :ContextModifiers => [
                    {
                      :Type => 'GemPath',
                      :Content => '%INSTALLDIR%'
                    }
                  ]
                }
              ]
            } )
          ],
          :possible_context_modifiers => {
            'WxRuby' => [
              [
                [ 'GemPath', lLocalGemsDir ]
              ]
            ]
          },
          :auto_install => RDI::DEST_OTHER,
          :auto_install_location => lLocalGemsDir
        )
        if ((lError == nil) and
            (lUnresolved.empty?))
          # Launch everything
          require 'wx'
          require 'pbs/MainApp'
          # Protect against errors
          begin
            MainApp.new(iPBSRootDir, @DebugOption, lOpenFileNames).main_loop
            set_gui_for_dialogs(nil)
            log_info 'PBS closed correctly.'
          rescue Exception
            set_gui_for_dialogs(nil)
            log_exc $!, 'Un exception occurred during PBS run.'
          end
        else
          log_err "Error while installing wxRuby: #{lError}. #{lUnresolved.size} unresolved dependencies. Exiting."
        end
      end
    end

    # Get command line parameters
    #
    # Return::
    # * _OptionParser_: The options parser
    def getOptions
      rOptions = OptionParser.new

      rOptions.banner = 'pbs [-d|--devdebug] [-l|--log <Logfile>] [-h|--help] <Files list>'
      rOptions.on('-d', '--devdebug',
        'Set developer debug interface.') do
        @DebugOption = true
      end
      rOptions.on('-h', '--help',
        'Display help usage.') do
        @DisplayUsage = true
      end
      rOptions.on('-l', '--log <Logfile>', String,
        '<Logfile>: Name of a file to log into.',
        'Set log file.') do |iArg|
        @LogFile = iArg
      end

      return rOptions
    end

  end

end

# We can't make any assumption about the current directory (Dir.getwd)
# Use the relative file path to know where are
PBS::Launcher.new.launch(File.expand_path("#{File.dirname(__FILE__)}/.."))
