#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Release a distribution of a Ruby program.
# This produces an installable executable that will install a set of files and directories:
# * A binary, including some core Ruby and program files (eventually the whole Ruby distribution if needed - that is if the program is meant to be run on platforms not providing Ruby)
# * A list of files/directories

module PBS
  
  class ReleaseInfo < RubyPackager::ReleaseInfo
    
    # Constructor
    # 
    # Parameters:
    # * *iRootDir* (_String_): The root dir
    # * *iIncludeRubyGems* (_Boolean_): Do we include RubyGems in the release ?
    # * *iIncludeWxRuby* (_Boolean_): Do we include WxRuby in the release ?
    # * *iIncludeAllExt* (_Boolean_): Do we include all ext directory in the release ?
    def initialize(iRootDir, iIncludeRubyGems, iIncludeWxRuby, iIncludeAllExt)
      @IncludeWxRuby = iIncludeWxRuby
      # Define needed attributes
      @Name = 'PBS'
      @Version = '0.0.6'
      @StartupRBFile = 'bin/pbs.rb'
      @ExeName = 'pbs'
      @IconName = "Distribution/#{RUBY_PLATFORM}/Icon.ico"
      @NSIFileName = "Distribution/#{RUBY_PLATFORM}/Installer/install.nsi"
      @TerminalApplication = false
      if (iIncludeRubyGems)
        @Version += 'G'
      end
      if (iIncludeWxRuby)
        @Version += 'W'
      end
      if (iIncludeAllExt)
        @Version += 'E'
      end
      @CoreFiles = [
        'AUTHORS',
        'LICENSE',
        'README',
        'ChangeLog',
        'Credits',
        'Tips.txt',
        'pbsversion.rb',
        'lib/pbs/*.rb',
        'lib/pbs/Common/*.rb',
        'lib/pbs/Controller/*.rb',
        'lib/pbs/Model/*.rb',
        'lib/pbs/Windows/*.rb',
        'lib/pbs/Windows/OptionsPanels/*.rb',
        'ext/rUtilAnts/**/*',
        'ext/RDI/**/*',
        'bin/pbs.rb'
      ]
      if (iIncludeRubyGems)
        # TODO
        #@CoreFiles << 'ext/rubygems/**/*'
      end
      @AdditionalFiles = [
        'lib/pbs/Plugins/**/*',
        'lib/pbs/Graphics/**/*'
      ]
      if (iIncludeAllExt)
        # Include everything in the external directory
        @AdditionalFiles << "ext/#{RUBY_PLATFORM}/**/*"
      elsif (iIncludeWxRuby)
        # Include WxRuby from the external directory
        lFound = false
        Dir.glob("#{iRootDir}/ext/#{RUBY_PLATFORM}/LocalGems/gems/wxruby*").each do |iFileName|
          if (File.directory?(iFileName))
            @AdditionalFiles << "#{iFileName}/**/*"
            lFound = true
          end
        end
        if (!lFound)
          puts "!!! No delivery of wxruby has been found in #{iRootDir}/ext/#{RUBY_PLATFORM}/wxruby*"
        end
      end
    end
    
    # Check if the tools needed for the release are ok
    # This is meant to be overriden if needed
    #
    # Parameters:
    # * *iRootDir* (_String_): Root directory from where the release is happening
    # Return:
    # * _Boolean_: Success ?
    def checkTools(iRootDir)
      rSuccess = true
      
      # Check that the tools we need to release are indeed here
      if (@IncludeWxRuby)
        if ((!File.exists?("#{iRootDir}/ext/#{RUBY_PLATFORM}/LocalGems/gems")) or
            (Dir.glob("#{iRootDir}/ext/#{RUBY_PLATFORM}/LocalGems/gems/wxruby*").empty?))
          puts "!!! Need to have wxruby installed in #{iRootDir}/ext/#{RUBY_PLATFORM}/LocalGems/gems to release including wxruby."
          rSuccess = false
        end
      end
      
      return rSuccess
    end
    
  end
  
end

$ReleaseInfo = PBS::ReleaseInfo.new(Dir.getwd, true, true, true)
