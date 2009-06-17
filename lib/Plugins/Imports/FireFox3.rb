#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# SQLite is required to read the complete bookmarks database of Firefox 3.
require 'sqlite3'
# Temp directory is used to store the favicon files on disk to read them, and also to eventually copy the database file if it is in use.
require 'tmpdir'
# Neeed to copy files
require 'fileutils'

module PBS

  module Imports

    class FireFox3

      # Give the description of this plugin
      #
      # Return:
      # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
      # ** :title (_String_): Name of the plugin
      # ** :description (_String_): Quick description
      # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
      def pluginInfo
        return {
          :title => 'FireFox 3',
          :description => 'Import Shortcuts from current FireFox 3 profile',
          :bitmapName => 'FireFox3.png',
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
          puts '!!! The environment variable USERPROFILE is not set. Impossible to get Google Chrome bookmarks.'
        else
          # Find the FireFox profiles dir
          lBookmarksFileName = nil
          Dir.glob("#{lProfileDir}/Application Data/Mozilla/Firefox/Profiles/*.default") do |iProfileDir|
            lBookmarksFileName = "#{iProfileDir}/places.sqlite"
          end
          if (lBookmarksFileName == nil)
            puts "!!! Can't find profile dir in #{lProfileDir}/Application Data/Mozilla/Firefox/Profiles/*.default"
          else
            if (!File.exists?(lBookmarksFileName))
              puts "!!! Bookmarks file #{lBookmarksFileName} does not exist."
            else
              # OK, now we open it and import its content
              ioController.undoableOperation('Import bookmarks from FireFox 3') do
                if (ioController.checkSavedWorkAndScratch(iParentWindow))
                  importBookmarksFromFirefox(ioController, lBookmarksFileName, ioController.RootTag)
                end
              end
            end
          end
        end
      end

      # Create Tags from the map read from the database
      #
      # Parameters:
      # * *ioController* (_Controller_): The Controller
      # * *ioFolderInfo* (<em>[ String, Integer, list< ... >, Tag ]): The folder info (need to fill the Tag in it)
      # * *ioParentTag* (_Tag_): The parent Tag where we want to import (can be the Root Tag).
      def createTags(ioController, ioFolderInfo, ioParentTag)
        iTitle, iParentID, iChildren, iNil = ioFolderInfo
        # Create the Tag
        lNewTag = ioController.createTag(ioParentTag, iTitle, nil)
        # Set our info
        ioFolderInfo[3] = lNewTag
        # Call recursively children
        iChildren.each do |ioChildInfo|
          createTags(ioController, ioChildInfo, lNewTag)
        end
      end

      # Import a single bookmark
      #
      # Parameters:
      # * *ioController* (_Controller_): The Controller
      # * *iFolders* (<em>map<Integer,[String,Integer,list<[...]>,Tag]></em>): The folders information
      # * *iParentID* (_Integer_): The parent folder ID
      # * *iURL* (_String_): The URL
      # * *iTitle* (_String_): Title
      # * *iIconBitmap* (<em>Wx::Bitmap</em>): The icon (or nil if none)
      def importBookmark(ioController, iFolders, iParentID, iURL, iTitle, iIconBitmap)
        # Tags
        lParentTag = nil
        if (iFolders[iParentID] != nil)
          lParentTag = iFolders[iParentID][3]
        end
        if (lParentTag == nil)
          puts "!!! Bookmark #{iTitle} belongs to folder ID #{iParentID}, which is unknown. Bookmark \"#{iTitle}\" will be added with no Tag."
        end
        lNewTags = {}
        # Beware the root Tag
        if (lParentTag != nil)
          lNewTags[lParentTag] = nil
        end
        # Create the new Shortcut
        ioController.createShortcut(
          'URL',
          iURL,
          {
            'title' => iTitle,
            'icon' => iIconBitmap
          },
          lNewTags
        )
      end

      # Import bookmarks from a database file used by FireFox 3
      #
      # Parameters:
      # * *ioController* (_Controller_): The Controller
      # * *iFileName* (_String_): The database file name
      # * *ioParentTag* (_Tag_): The parent Tag where we want to import (can be the Root Tag).
      def importBookmarksFromFirefox(ioController, iFileName, ioParentTag)
        # Open the DB and import everything
        lNewFileName = nil
        lBMDB = SQLite3::Database.new(iFileName)
        begin
          # Issue a single select to test if the database is in use
          lBMDB.execute("SELECT id FROM moz_bookmarks WHERE id = 1")
        rescue SQLite3::BusyException
          # The database is in use.
          # Try copying the file in another place.
          lNewFileName = "#{Dir.tmpdir}/FF3DB_#{self.object_id}.sqlite"
          FileUtils::cp(iFileName, lNewFileName)
          # Try again
          lBMDB = SQLite3::Database.new(lNewFileName)
        end
        # Here we have a working DB.
        # Types:
        # 1 = Bookmark
        # 2 = Folder
        # We temporarily store the folders data in a hash map
        # map< Integer, [ String, Integer, list< [ ... ] >, Tag ] >
        # map< ID, [ Title, ParentID, list< ChildrenInfo >, CorrespondingTag ] >
        lFolders = {}
        # First select folders
        lBMDB.execute("
          SELECT
            id,
            parent,
            title
          FROM
            moz_bookmarks
          WHERE
            type = \"2\" AND
            title <> \"\"
        ") do |iRow|
          iID, iParentID, iTitle = iRow
          lFolders[iID] = [ iTitle, iParentID, [], nil ]
        end
        # Then create links to the children maps, and remember which ones do not have parents
        # list< Integer >
        lRootFolders = []
        lFolders.each do |iID, ioFolderInfo|
          if (lFolders[ioFolderInfo[1]] == nil)
            # No parent
            lRootFolders << iID
          else
            # Add ourselves as a child of our parent
            lFolders[ioFolderInfo[1]][2] << ioFolderInfo
          end
        end
        # Create all corresponding Tags
        lRootFolders.each do |iRootID|
          createTags(ioController, lFolders[iRootID], ioParentTag)
        end
        # Now, all Tags have been created, and for each Folder ID we have the corresponding Tag in lFolders[ID][3]
        # We read bookmarks that have icons
        lBMDB.execute("
          SELECT
            b.parent,
            b.title,
            p.url,
            f.data,
            f.mime_type
          FROM
            moz_bookmarks b,
            moz_places p,
            moz_favicons f
          WHERE
            b.type = \"1\" AND
            b.fk = p.id AND
            p.favicon_id = f.id AND
            b.title is not NULL
        ") do |iRow|
          iParentID, iTitle, iURL, iIconData, iIconType = iRow
          # The icon
          # Write its data in a temporary file
          lIconFileName = "#{Dir.tmpdir}/Favicon_#{self.object_id}"
          File.open(lIconFileName, 'wb') do |oFile|
            oFile.write(iIconData)
          end
          # Translate some unknown mime/type to WxRuby's types
          lBitmapType = iIconType
          case iIconType
          when 'image/x-icon'
            lBitmapType = Wx::BITMAP_TYPE_ICO
          when 'image/bmp'
            lBitmapType = Wx::BITMAP_TYPE_BMP
          end
          # Read the file
          lIconBitmap = Wx::Bitmap.from_image(Wx::Image.new(lIconFileName, lBitmapType))
          # Delete the temporary file
          File.unlink(lIconFileName)
          importBookmark(ioController, lFolders, iParentID, iURL, iTitle, lIconBitmap)
        end
        # Now we read bookmarks that don't have any icons
        lBMDB.execute("
          SELECT
            b.parent,
            b.title,
            p.url
          FROM
            moz_bookmarks b,
            moz_places p
          WHERE
            b.type = \"1\" AND
            b.fk = p.id AND
            p.favicon_id is NULL AND
            b.title is not NULL
        ") do |iRow|
          iParentID, iTitle, iURL = iRow
          importBookmark(ioController, lFolders, iParentID, iURL, iTitle, nil)
        end
        # Close
        lBMDB.close
        # Remove eventually temporary file
        if (lNewFileName != nil)
          File.unlink(lNewFileName)
        end
      end

    end

  end

end