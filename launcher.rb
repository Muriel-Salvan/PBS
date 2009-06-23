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
    # * *iLauncher* (_Object_): The launcher containing platform dependent methods
    def launch(iRootDir, iLauncher)
      # Global paths
      # Root dir used as a based for images directories, plugins to be required...
      $PBS_RootDir = iRootDir
      $PBS_LibDir = "#{$PBS_RootDir}/lib"
      $PBS_GraphicsDir = "#{$PBS_LibDir}/Graphics"
      $PBS_ExtDir = "#{$PBS_RootDir}/ext/#{RUBY_PLATFORM}"
      $PBS_ExtGemsDir = "#{$PBS_ExtDir}/gems"
      # Add the main library directory to the load path
      $LOAD_PATH << $PBS_LibDir
      require 'Tools.rb'
      self.class.instance_eval('include Tools')
      if (ensureWxRuby(iLauncher))
        # Launch everything
        require 'pbs'
        PBS::run
      else
        iLauncher.sendMsg('Unable to start PBS. Exiting.')
      end
    end

  end

end
