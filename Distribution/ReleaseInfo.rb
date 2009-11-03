#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

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
      super()
      @IncludeWxRuby = iIncludeWxRuby
      # Define needed attributes
      author(
        :Name => 'Muriel Salvan',
        :EMail => 'murielsalvan@users.sourceforge.net',
        :WebPageURL => 'http://murielsalvan.users.sourceforge.net'
      )
      project(
        :Name => 'PBS: Portable Bookmarks and Shortcuts',
        :WebPageURL => 'http://pbstool.sourceforge.net/',
        :Summary => 'Cross-platform explorer shipping your Internet bookmarks and workspace\'s shortcuts.',
        :Description => 'Cross platform GUI managing bookmarks and shortcuts in a portable way. Support import/export, search, encryption, hierarchical tags, USB key installation, various environments integration, OS-dependent shortcuts, plugins extensibility.',
        :ImageURL => 'http://pbstool.sourceforge.net/wiki/images/2/26/Favicon.png',
        :FaviconURL => 'http://pbstool.sourceforge.net/wiki/images/2/26/Favicon.png',
        :SVNBrowseURL => 'http://pbstool.svn.sourceforge.net/viewvc/pbstool/',
        :DevStatus => 'Alpha'
      )
      addCoreFiles( [
        'Tips.txt',
        'lib/pbs/*.rb',
        'lib/pbs/Common/*.rb',
        'lib/pbs/Controller/*.rb',
        'lib/pbs/Model/*.rb',
        'lib/pbs/Windows/*.rb',
        'lib/pbs/Windows/OptionsPanels/*.rb',
        'ext/rUtilAnts/**/*',
        'ext/RDI/**/*',
        'bin/pbs.rb'
      ] )
      addAdditionalFiles( [
        'AUTHORS',
        'LICENSE',
        'README',
        'ChangeLog',
        'Credits',
        'lib/pbs/Plugins/**/*',
        'lib/pbs/Graphics/**/*'
      ] )
      if (iIncludeAllExt)
        # Include everything in the external directory
        addAdditionalFiles( [
          "ext/#{RUBY_PLATFORM}/**/*"
        ] )
      elsif (iIncludeWxRuby)
        # Include WxRuby from the external directory
        lFound = false
        Dir.glob("#{iRootDir}/ext/#{RUBY_PLATFORM}/LocalGems/gems/wxruby*").each do |iFileName|
          if (File.directory?(iFileName))
            addAdditionalFiles( [
              "#{iFileName}/**/*"
            ] )
            lFound = true
          end
        end
        if (!lFound)
          puts "!!! No delivery of wxruby has been found in #{iRootDir}/ext/#{RUBY_PLATFORM}/wxruby*"
        end
      end
      gem(
        :GemName => 'PBS',
        :GemPlatformClassName => 'Gem::Platform::RUBY',
        :RequirePath => 'lib',
        :HasRDoc => true,
        :GemDependencies => [
          [ 'rUtilAnts', '>= 0.1' ],
          [ 'RDI', '>= 0.1' ]
        ]
      )
      sourceForge(
        :Login => 'murielsalvan',
        :ProjectUnixName => 'pbstool'
      )
      rubyForge(
        :ProjectUnixName => 'pbs'
      )
      executable(
        :StartupRBFile => 'bin/pbs.rb',
        :ExeName => 'pbs',
        :IconName => "Distribution/#{RUBY_PLATFORM}/Icon.ico",
        :TerminalApplication => false
      )
      install(
        :NSISFileName => "Distribution/#{RUBY_PLATFORM}/Installer/install.nsi",
        :InstallerName => 'pbs'
      )
    end
    
    # Check if the tools needed for the release are ok
    # This is meant to be overriden if needed
    #
    # Parameters:
    # * *iRootDir* (_String_): Root directory from where the release is happening
    # Return:
    # * _Boolean_: Success ?
    def checkReadyForRelease(iRootDir)
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

PBS::ReleaseInfo.new(Dir.getwd, true, true, true)
