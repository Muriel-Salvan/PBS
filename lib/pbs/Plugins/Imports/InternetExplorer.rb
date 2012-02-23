#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Imports

    class InternetExplorer

      # Execute the import
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParentWindow)
        # Get the profile bookmarks path from the registry
        lFavoritesPath = nil
        begin
          require 'win32/registry'
          Win32::Registry::HKEY_CURRENT_USER.open('Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders') do |iReg|
            lRegType, lFavoritesPath = iReg.read('Favorites')
            lFavoritesPath.gsub!(/\\/,'/')
          end
        rescue Exception
          log_err "Unable to get the favorites path: #{$!}."
          lFavoritesPath = nil
        end
        if (lFavoritesPath == nil)
          log_err 'Unable to read the favorites path from Windows registry.'
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