#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'win32/registry'

module PBS

  module Imports

    class InternetExplorer

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
            lFavoritesPath.gsub!(/\\/,'/')
          end
        rescue Exception
          logErr "Unable to get the favorites path: #{$!}."
          lFavoritesPath = nil
        end
        if (lFavoritesPath == nil)
          logErr 'Unable to read the favorites path from Windows registry.'
        else
          # Use the WebBookmarks import plugin
          ioController.undoableOperation('Import bookmarks from Internet Explorer') do
            if (ioController.checkSavedWorkAndScratch(iParentWindow))
              PBS::Imports::WebBookmarks.new.importWebBookmarks(ioController, lFavoritesPath, ioController.RootTag)
            end
          end
        end
      end

    end

  end

end