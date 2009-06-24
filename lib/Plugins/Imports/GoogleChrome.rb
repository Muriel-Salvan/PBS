#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'iconv'
# SQLite is required to read the favicons database of Google Chrome.
require 'sqlite3'
# Temp directories are used to store the favicon files on disk to read them
require 'tmpdir'

module PBS

  module Imports

    class GoogleChrome

      include Tools

      # The Google Chrome names to UTF-8 converter
      UTF8_CONVERTER = Iconv.new('UTF-8', 'CP1252')

      # Class that encapsulate the calls to SQLite to get the favicons
      class FaviconsProvider
        
        include Tools

        # Create a new Favicon provider, and ensure it will be closed
        #
        # Parameters:
        # * iFileName* (_String_): The database file name
        # * *CodeBlock*: Code to be called when the provider is ready to accept queries
        # ** *iProvider* (_FaviconsProvider_): The resulting favicons provider
        def self.createProvider(iFileName)
          lProvider = FaviconsProvider.new(iFileName)
          yield(lProvider)
          lProvider.final
        end

        # Constructor
        #
        # Parameters:
        # * iFileName* (_String_): The database file name
        def initialize(iFileName)
          @FaviconsDB = nil
          if (File.exists?(iFileName))
            logErr "Favicons database #{iFileName} does not exist. Shortcuts will be created without favicons."
            # First get the database storing favicons
            @FaviconsDB = SQLite3::Database.new(iFileName)
            # As we open a large file (often around 50Mb for Google Chrome favicons), we increase the cache size.
            @FaviconsDB.execute("PRAGMA cache_size=50000")
          end
        end

        # Destructor
        def final
          if (@FaviconsDB != nil)
            @FaviconsDB.close
          end
        end

        # Get the favicon for a given server
        #
        # Parameters:
        # * *iServerURL* (_String_): Name of the Server (contains the http:// also)
        # Return:
        # * <em>Wx::Bitmap</em>: The icon, or nil if none
        def getFavicon(iServerURL)
          rBitmap = nil

          if (@FaviconsDB != nil)
            begin
              @FaviconsDB.execute("SELECT image_data FROM favicons WHERE url LIKE \"#{iServerURL}%/favicon.ico\"") do |iFaviconData|
                if (iFaviconData[0] != nil)
                  # Write this data in a temporary file
                  lFileName = "#{Dir.tmpdir}/Favicon_#{self.object_id}.png"
                  File.open(lFileName, 'wb') do |oFile|
                    oFile.write(iFaviconData[0])
                  end
                  # Read the file
                  rBitmap = Wx::Bitmap.new(lFileName, Wx::BITMAP_TYPE_PNG)
                  # Delete the temporary file
                  File.unlink(lFileName)
                end
              end
            rescue Exception
              logBug "Error while reading favicon for server #{iServerURL}: #{$!}"
              rBitmap = nil
            end
          end

          return rBitmap
        end

      end

      # Give the description of this plugin
      #
      # Return:
      # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
      # ** :title (_String_): Name of the plugin
      # ** :description (_String_): Quick description
      # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
      def pluginInfo
        return {
          :title => 'Google Chrome',
          :description => 'Import Shortcuts from current Google Chrome profile',
          :bitmapName => 'GoogleChrome.png',
        }
      end

      # Execute the import
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParentWindow)
        # Get the profile path from the environment
        lProfileDir = ENV['USERPROFILE']
        if (lProfileDir == nil)
          logErr 'The environment variable USERPROFILE is not set. Impossible to get Google Chrome bookmarks.'
        else
          lBookmarksFileName = "#{lProfileDir}/Local Settings/Application Data/Google/Chrome/User Data/Default/Bookmarks"
          if (!File.exists?(lBookmarksFileName))
            logErr "Bookmarks file #{lBookmarksFileName} does not exist."
          else
            # OK, now we open it and import its content
            ioController.undoableOperation('Import bookmarks from Google Chrome') do
              if (ioController.checkSavedWorkAndScratch(iParentWindow))
                FaviconsProvider.createProvider("#{lProfileDir}/Local Settings/Application Data/Google/Chrome/User Data/Default/Thumbnails") do |iProvider|
                  importChromeBookmarksFile(ioController, iProvider, lBookmarksFileName, ioController.RootTag)
                end
              end
            end
          end
        end
      end

      # Import bookmarks from a Google Chrome bookmarks file
      #
      # Parameters:
      # * *ioController* (_Controller_): The Controller
      # * *iFaviconsProvider* (_FaviconsProvider_): The favicons provider
      # * *iFileName* (_String_): The file name
      # * *ioParentTag* (_Tag_): The Tag in which we import bookmarks (can be the Root Tag)
      def importChromeBookmarksFile(ioController, iFaviconsProvider, iFileName, ioParentTag)
        # We read the file, replacing each '"key": value' with '"key" => value', and it's magic: we will get a pure Ruby object from Google Chrome.
        lFileContent = ''
        File.open(iFileName, 'r') do |iFile|
          iFile.readlines.each do |iLine|
            # Match lines to replace : with =>
            lMatch = iLine.match(/^([[:space:]]*"[^"]*"): (.*)$/)
            if (lMatch != nil)
              lFileContent += "#{lMatch[1]} => #{lMatch[2]}\n"
            else
              lFileContent += "#{iLine}\n"
            end
          end
        end
        # Now lFileContent contains a real Ruby object. Instantiate it.
        lCancel = false
        begin
          lBookmarks = eval(lFileContent)
        rescue Exception
          logBug "Error while reading the bookmarks content from file #{iFileName}: #{$!}."
          lCancel = true
        end
        if (!lCancel)
          # Interpret the bookmarks map. Here is the structure used by Google Chrome:
          # Item = map<
          #   'type' => 'url' or 'folder'
          #   'name' => String
          #   'url' => String (if type url)
          #   'children' => list< Item > (if type folder)
          # >
          lBookmarks['roots'].each do |iName, iItem|
            importGoogleChromItem(ioController, iFaviconsProvider, iItem, ioParentTag)
          end
        end
      end

      # Import a Google Chrome item.
      #
      # Parameters:
      # * *ioController* (_Controller_): The Controller
      # * *iFaviconsProvider* (_FaviconsProvider_): The favicons provider
      # * *iItem* (<em>map<String,Object></em>): The Google Chrome item
      # * *ioParentTag* (_Tag_): The Tag in which we import bookmarks (can be the Root Tag)
      def importGoogleChromItem(ioController, iFaviconsProvider, iItem, ioParentTag)
        case iItem['type']
        when 'url'
          # We create a new Shortcut
          lTitle = UTF8_CONVERTER.iconv(iItem['name'])
          lURL = iItem['url']
          # Extract the web server name if it is not a file
          lIconBitmap = nil
          lMatch = lURL.match(/^(http|https|ftp|ftps):\/\/([^\/]*).*$/)
          if (lMatch == nil)
            # Check an eventual file (in this case, no icon)
            lMatch = lURL.match(/^(file):\/\/([^\/]*).*$/)
            if (lMatch == nil)
              logBug "Impossible to get the server name of URL #{lURL}. There will be no favicon for Shortcut #{lTitle}."
            end
          else
            lIconBitmap = iFaviconsProvider.getFavicon("#{lMatch[1]}://#{lMatch[2]}")
          end
          # Tags
          lNewTags = {}
          # Beware the root Tag
          if (ioParentTag != ioController.RootTag)
            lNewTags[ioParentTag] = nil
          end
          # Create the new Shortcut
          ioController.createShortcut(
            'URL',
            lURL,
            {
              # Convert the file name in UTF-8
              'title' => lTitle,
              'icon' => lIconBitmap
            },
            lNewTags
          )
        when 'folder'
          # We create a new Tag
          lNewTag = ioController.createTag(ioParentTag, UTF8_CONVERTER.iconv(iItem['name']), nil)
          # We parse children
          iItem['children'].each do |iChildItem|
            importGoogleChromItem(ioController, iFaviconsProvider, iChildItem, lNewTag)
          end
        else
          logBug "Unknown Item Type: #{iItem['type']}. Ignoring item #{iItem['name']}."
        end
      end

    end

  end

end