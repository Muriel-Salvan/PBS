#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'fileutils'

module PBS

  module Exports

    class Files

      include Tools

      # Get the title to display in the commands for this plugin
      #
      # Return:
      # * _String_: The title
      def getTitle
        return 'Files and folders'
      end

      # Get the icon sub-path, relative to PBS root directory
      #
      # Return:
      # * _String_: The icon sub-path
      def getIconSubPath
        return 'Graphics/Tag.png'
      end

      # Execute the export
      #
      # Parameters:
      # * *iController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(iController, iParentWindow)
        # Display Open directory Dialog
        showModal(Wx::DirDialog, iParentWindow,
          :message => 'Open directory saving web bookmarks'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            # First, create the Tags hierarchy
            # Keep a correspondance between a Tag and its corresponding directory
            # map< Tag, String >
            lTagsToPaths = {}
            createTagsInDir(iController.RootTag, iDialog.path, lTagsToPaths)
            # Then export Shortcuts
            iController.ShortcutsList.each do |iShortcut|
              if (iShortcut.Tags.empty?)
                exportShortcut(iController, iShortcut, iDialog.path)
              else
                iShortcut.Tags.each do |iTag, iNil|
                  exportShortcut(iController, iShortcut, lTagsToPaths[iTag])
                end
              end
            end
          end
        end
      end

      # Create Tags in a directory
      #
      # Parameters:
      # * *iTag* (_Tag_): Tag to map in the given directory
      # * *iPath* (_String_): Path mapped to iTag
      # * *oTagsToPaths* (<em>map<Tag,String></em>): Correspondance between Tags and paths
      def createTagsInDir(iTag, iPath, oTagsToPath)
        iTag.Children.each do |iChildTag|
          # Make sure the name only has valid characters
          lChildPath = "#{iPath}/#{getValidFileName(iChildTag.Name)}"
          FileUtils.mkdir_p(lChildPath)
          oTagsToPath[iChildTag] = lChildPath
          createTagsInDir(iChildTag, lChildPath, oTagsToPath)
        end
      end

      # Export a Shortcut in a directory
      #
      # Parameters:
      # * *iController* (_Controller_): The controller
      # * *iShortcut* (_Shortcut_): The Shortcut to export
      # * *iPath* (_String_): Directory in which we export the Shortcut
      def exportShortcut(iController, iShortcut, iPath)
        # Here we have to know how to export the different Shortcut types.
        # Maybe add a generic function to each Shortcut type ?
        case iShortcut.Type
        when iController.TypesPlugins['URL']
          File.open("#{iPath}/#{getValidFileName(iShortcut.Metadata['title'])}.url", 'w') do |oFile|
            oFile << "[InternetShortcut]
URL=#{iShortcut.Content}
"
          end
        else
          puts "!!! Can't create a file for Shortcuts of type #{iShortcut.Type.pluginName}."
        end
      end

    end

  end

end