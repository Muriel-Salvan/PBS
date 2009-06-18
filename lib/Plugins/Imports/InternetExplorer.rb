#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'win32/registry'

module PBS

  module Imports

    class InternetExplorer

      include Tools

      # Give the description of this plugin
      #
      # Return:
      # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
      # ** :title (_String_): Name of the plugin
      # ** :description (_String_): Quick description
      # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
      def pluginInfo
        return {
          :title => 'Internet Explorer',
          :description => 'Import Shortcuts from current Internet Explorer profile',
          :bitmapName => 'InternetExplorer.png',
        }
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
          logErr "Unable to get the favorites path: #{$!}."
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
            logBug "Import plugin WebBookmarks not found. InternetExplorer import depends on it."
          end
        end
      end

    end

  end

end