#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This is necessary to convert file names (used as Shortcut/Tags titles) into UTF-8, as this is necessary for them to be displayed correctly in WxRuby.
require 'iconv'

module PBS

  module Imports

    class WebBookmarks

      include Tools

      # The file names to UTF-8 converter
      UTF8_CONVERTER = Iconv.new('UTF-8', 'CP1252')

      # All extensions we try to read (uppercase only)
      POSSIBLE_EXTENSIONS = [ '.URL' ]

      # Execute the import
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParentWindow)
        # Display Open directory Dialog
        showModal(Wx::DirDialog, iParentWindow,
          :message => 'Open directory containing web bookmarks'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            ioController.undoableOperation("Import bookmarks from #{File.basename(iDialog.path)}") do
              if (ioController.checkSavedWorkAndScratch(iParentWindow))
                importWebBookmarks(ioController, iDialog.path, ioController.RootTag)
              end
            end
          end
        end
      end

      # Import a Shortcut from a file
      #
      # Parameters:
      # * *ioController* (_Controller_): The controller
      # * *iFileName* (_String_): The file containing the Shortcut
      # * *iParentTag* (_Tag_): The parent Tag in which the Shortcut has been found (can be the Root Tag)
      def importShortcutFromFile(ioController, iFileName, iParentTag)
        # Read the file as a text file
        lURL = nil
        lIconFile = nil
        lIconIndex = nil
        File.open(iFileName, 'r') do |iFile|
          iFile.readlines.each do |iLine|
            # Try matching the URL
            lMatch = iLine.match(/^URL=(.*)$/)
            if (lMatch != nil)
              lURL = lMatch[1]
            else
              # Try matching the Icon
              lMatch = iLine.match(/^IconFile=(.*)$/)
              if (lMatch != nil)
                lIconFile = lMatch[1]
              else
                # Try matching the icon index
                lMatch = iLine.match(/^IconIndex=(.*)$/)
                if (lMatch != nil)
                  lIconIndex = lMatch[1].to_i
                end
              end
            end
            # Break if we want nothing more
            if ((lURL != nil) and
                (lIconFile != nil) and
                (lIconIndex != nil))
              break
            end
          end
        end
        # Now create the Shortcut based on what we got
        if (lURL != nil)
          # Get the icon
          lIconBitmap = nil
          if (lIconFile != nil)
            lIconBitmap = getBitmapFromFile(lIconFile, lIconIndex)
          end
          # Tags
          lNewTags = {}
          # Beware the root Tag
          if (iParentTag != ioController.RootTag)
            lNewTags[iParentTag] = nil
          end
          # Create the new Shortcut
          ioController.createShortcut(
            'URL',
            lURL,
            {
              # Convert the file name in UTF-8, and remove extension
              'title' => UTF8_CONVERTER.iconv(File.basename(iFileName[0..-1-File.extname(iFileName).size])),
              'icon' => lIconBitmap
            },
            lNewTags
          )
        else
          logBug "File #{iFileName} does not define any URL (could not find any line 'URL='). Ignoring this file."
        end
      end

      # Import Web Bookmarks from a directory
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iDirName* (_String_): Directory name
      # * *iTag* (_Tag_): Tag in which we add Shortcuts of this directory
      def importWebBookmarks(ioController, iDirName, iTag)
        Dir.glob("#{iDirName}/*") do |iFileName|
          if (File.directory?(iFileName))
            if ((iFileName != '.') and
                (iFileName != '..'))
              # A new Tag
              lNewTag = ioController.createTag(iTag, UTF8_CONVERTER.iconv(File.basename(iFileName)), nil)
              importWebBookmarks(ioController, iFileName, lNewTag)
            end
          elsif (POSSIBLE_EXTENSIONS.include?(File.extname(iFileName).upcase))
            # A candidate file
            importShortcutFromFile(ioController, iFileName, iTag)
          end
        end
      end

    end

  end

end