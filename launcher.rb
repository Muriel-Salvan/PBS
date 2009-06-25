#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  class Launcher

    # 1. Setup environment (global variables)
    # 2. Check wxruby ok
    # 3. Run PBS
    #
    # Parameters:
    # * *iRootDir* (_String_): The root dir of PBS
    # * *iPlatform* (_Object_): The object containing platform dependent methods
    def launch(iRootDir, iPlatform)
      # The platform dependent object
      $PBS_Platform = iPlatform
      # Global paths
      # Root dir used as a based for images directories, plugins to be required...
      $PBS_RootDir = iRootDir
      $PBS_LibDir = "#{$PBS_RootDir}/lib"
      $PBS_GraphicsDir = "#{$PBS_LibDir}/Graphics"
      $PBS_ExtDir = "#{$PBS_RootDir}/ext/#{RUBY_PLATFORM}"
      $PBS_ExtGemsDir = "#{$PBS_ExtDir}/gems"
      $PBS_ExtDllsDir = "#{$PBS_ExtDir}/libs"
      # Add the main library directory to the load path, as well as libraries needed for PBS without plugins
      $LOAD_PATH.concat( [
        $PBS_LibDir,
        "#{$PBS_RootDir}/ext/rubyzip-0.9.1/lib"
      ] )
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
