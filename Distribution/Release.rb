#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Release a distribution of PBS
# This file is used directly from the root dir

require 'fileutils'

# Require the platform specific distribution file
require "Distribution/#{RUBY_PLATFORM}/ReleaseInfo.rb"

module PBS

  module Distribution
    
    # Class that makes a release
    class Releaser

      # Log an operation, and call some code inside
      #
      # Parameters:
      # * *iOperationName* (_String_): Operation name
      # * *CodeBlock*: Code to call in this operation
      def logOp(iOperationName)
        puts "===== #{iOperationName} ..."
        yield
        puts "===== ... #{iOperationName}"
      end

      # Constructor
      #
      # Parameters:
      # * *iPBSRootDir* (_String_): PBS root dir
      # * *iPlatformReleaseInfo* (_Object_): The platform dependent release info
      def initialize(iPBSRootDir, iPlatformReleaseInfo)
        @PBSRootDir = iPBSRootDir
        @PlatformReleaseInfo = iPlatformReleaseInfo
      end

      # Copy a list of files patterns to the release directory
      #
      # Parameters:
      # * *iFilesPatterns* (<em>list<String></em>): The list of files patterns
      def copyFiles(iFilesPatterns)
        iFilesPatterns.each do |iFilePattern|
          Dir.glob(iFilePattern).each do |iFileName|
            if (iFileName.match(/\.svn/) == nil)
              lRelativeName = nil
              # Extract the relative file name
              lMatch = iFileName.match(/^#{@PBSRootDir}\/(.*)$/)
              if (lMatch == nil)
                # The path is already relative
                lRelativeName = iFileName
              else
                lRelativeName = lMatch[1]
              end
              lDestFileName = "#{@ReleaseDir}/#{lRelativeName}"
              FileUtils::mkdir_p(File.dirname(lDestFileName))
              if (File.directory?(iFileName))
                puts "Create directory #{lRelativeName}"
              else
                puts "Copy file #{lRelativeName}"
                FileUtils::cp(iFileName, lDestFileName)
              end
            end
          end
        end
      end

      # Execute a release
      #
      # Parameters:
      # * *iIncludeRuby* (_Boolean_): Do we include Ruby in the release ?
      # * *iIncludeRubyGems* (_Boolean_): Do we include RubyGems in the release ?
      # * *iIncludeWxRuby* (_Boolean_): Do we include WxRuby in the release ?
      # * *iIncludeAllExt* (_Boolean_): Do we include all ext directory in the release ?
      # Return:
      # * _Boolean_: Success ?
      def execute(iIncludeRuby, iIncludeRubyGems, iIncludeWxRuby, iIncludeAllExt)
        rSuccess = true

        # Compute the release directory name
        @ReleaseDir = "#{@PBSRootDir}/Releases/#{RUBY_PLATFORM}/#{Time.now.strftime('%Y_%m_%d_%H_%M_%S')}"
        # Add options to the directory name
        if (iIncludeRuby)
          @ReleaseDir += '_Ruby'
        end
        if (iIncludeRubyGems)
          @ReleaseDir += '_Gems'
        end
        if (iIncludeWxRuby)
          @ReleaseDir += '_Wx'
        end
        if (iIncludeAllExt)
          @ReleaseDir += '_Ext'
        end
        logOp('Check installed tools') do
          # Check that the tools we need to release are indeed here
          if (iIncludeWxRuby)
            if ((!File.exists?("#{@PBSRootDir}/ext/#{RUBY_PLATFORM}")) or
                (Dir.glob("#{@PBSRootDir}/ext/#{RUBY_PLATFORM}/wxruby*").empty?))
              puts "!!! Need to have wxruby installed in #{@PBSRootDir}/ext/#{RUBY_PLATFORM} to release including wxruby."
              rSuccess = false
            end
          end
          # Check tools for platform dependent considerations
          lPlatformSuccess = @PlatformReleaseInfo.checkTools(@PBSRootDir, iIncludeRuby)
          if (!lPlatformSuccess)
            rSuccess = false
          end
        end
        if (rSuccess)
          logOp('Copy core files') do
            # Copy in this directory every file that is not platform dependent
            # The core application (that could be bundled in a single binary - crate soon):
            # * LICENSE
            # * lib/*.rb
            # * lib/Controller/*.rb
            # * lib/Model/*.rb
            # * lib/Windows/*.rb
            # * ext/rubygems/**/* (if include RubyGems)
            # * ext/rubyzip-0.9.1/**/*
            # * ext/#{RUBY_PLATFORM}/zlib/**/*
            # * Launch/Launcher.rb
            # * Launch/#{RUBY_PLATFORM}/PlatformInfo.rb
            # * Ruby itself (if include Ruby)
            lCoreFilesList = [
              'LICENSE',
              'lib/*.rb',
              'lib/Controller/*.rb',
              'lib/Model/*.rb',
              'lib/Windows/*.rb',
              'ext/rubyzip-0.9.1/**/*',
              "ext/#{RUBY_PLATFORM}/zlib/**/*",
              'Launch/Launcher.rb',
              "Launch/#{RUBY_PLATFORM}/PlatformInfo.rb"
            ]
            if (iIncludeRubyGems)
              lCoreFilesList << 'ext/rubygems/**/*'
            end
            # Copy each file corresponding to every pattern in the bin directory
            copyFiles(lCoreFilesList)
          end
          logOp('Create binary') do
            # Application core is copied
            # TODO (crate): When crate will work correctly under Windows, use it here to pack everything
            # For now the executable creation is platform dependent
            rSuccess = @PlatformReleaseInfo.createBinary(@PBSRootDir, @ReleaseDir, iIncludeRuby)
          end
          if (rSuccess)
            logOp('Copy plugin files') do
              # And now copy plugin files
              # * lib/Plugins/**/*
              # * lib/Graphics/**/*
              # * ext/#{RUBY_PLATFORM}/wxruby* (if include wxruby)
              lFilesList = [
                'lib/Plugins/**/*',
                'lib/Graphics/**/*'
              ]
              if (iIncludeWxRuby)
                # WxRuby
                lFound = false
                Dir.glob("#{@PBSRootDir}/ext/#{RUBY_PLATFORM}/wxruby*").each do |iFileName|
                  if (File.directory?(iFileName))
                    lFilesList << "#{iFileName}/**/*"
                    lFound = true
                  end
                end
                if (!lFound)
                  puts "!!! No delivery of wxruby has been found in #{@PBSRootDir}/ext/#{RUBY_PLATFORM}/wxruby*"
                end
              end
              copyFiles(lFilesList)
            end
            if (iIncludeAllExt)
              logOp('Copy all ext files') do
                lExtFilesList = []
                # * ext/#{RUBY_PLATFORM}/**/* (except wxruby and zlib that were copied before)
                Dir.glob("#{@PBSRootDir}/ext/#{RUBY_PLATFORM}/*").each do |iFileName|
                  if ((File.directory?(iFileName)) and
                      (iFileName.match(/wxruby/) == nil) and
                      (File.basename(iFileName) != 'zlib'))
                    lExtFilesList << "#{iFileName}/**/*"
                  end
                end
                copyFiles(lExtFilesList)
              end
            end
            logOp('Create installer') do
              # Create the installer for this distribution
              # TODO
            end
          else
            puts "!!! Unable to create the platform dependent binary."
          end
        else
          puts "!!! Some tools needed to release are missing."
        end

        return rSuccess
      end

    end

  end

end

# Execute everything
if ($0 == __FILE__)
  lSuccess = PBS::Distribution::Releaser.new(Dir.getwd, PBS::Distribution::ReleaseInfo.new).execute(true, true, true, true)
  if (lSuccess)
    puts 'Release successful.'
  else
    puts 'Error while releasing.'
  end
end
