#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'win32/registry'

module PBS

  module Imports

    class InternetExplorer

      # Get the title to display in the commands for this plugin
      #
      # Return:
      # * _String_: The title
      def getTitle
        return 'Internet Explorer'
      end

      # Get the icon sub-path, relative to PBS root directory
      #
      # Return:
      # * _String_: The icon sub-path
      def getIconSubPath
        return 'Graphics/InternetExplorer.png'
      end

      # Execute the import
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParentWindow)
        # Get the profile bookmarks path from the registry
        lFavoritesPath = nil
        begin
          Win32::Registry::HKEY_CURRENT_USER.open('Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders') do |iReg|
            lRegType, lFavoritesPath = iReg.read('Favorites')
          end
        rescue Exception
          puts "!!! Unable to get the favorites path: #{$!}."
          lFavoritesPath = nil
        end
        if (lFavoritesPath != nil)
          # Use the WebBookmarks import plugin
          if (PBS::Imports.const_defined?(:WebBookmarks))
            ioController.undoableOperation('Import bookmarks from Internet Explorer') do
              if (ioController.checkSavedWorkAndScratch(iParentWindow))
                PBS::Imports::WebBookmarks.new.importWebBookmarks(ioController, lFavoritesPath, ioController.RootTag)
              end
            end
          else
            puts "!!! Import plugin WebBookmarks not found. InternetExplorer import depends on it."
          end
        end
      end

    end

  end

end