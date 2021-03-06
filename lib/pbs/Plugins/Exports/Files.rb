#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Exports

    class Files

      # Execute the export
      #
      # Parameters::
      # * *iController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(iController, iParentWindow)
        # Display Open directory Dialog
        showModal(Wx::DirDialog, iParentWindow,
          :message => 'Open directory saving web bookmarks'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            iController.undoableOperation("Export in directory #{iDialog.path}") do
              # First, create the Tags hierarchy
              # Keep a correspondance between a Tag and its corresponding directory
              # map< Tag, String >
              lTagsToPaths = {}
              iController.setProgressionText('Create Tags')
              createTagsInDir(iController.RootTag, iDialog.path, lTagsToPaths)
              # Then export Shortcuts
              iController.setProgressionText('Create Shortcuts')
              iController.addProgressionRange(iController.ShortcutsList.size)
              iController.ShortcutsList.each do |iShortcut|
                if (iShortcut.Tags.empty?)
                  exportShortcut(iController, iShortcut, iDialog.path)
                else
                  iShortcut.Tags.each do |iTag, iNil|
                    exportShortcut(iController, iShortcut, lTagsToPaths[iTag])
                  end
                end
                iController.incProgression
              end
            end
          end
        end
      end

      # Create Tags in a directory
      #
      # Parameters::
      # * *iTag* (_Tag_): Tag to map in the given directory
      # * *iPath* (_String_): Path mapped to iTag
      # * *oTagsToPaths* (<em>map<Tag,String></em>): Correspondance between Tags and paths
      def createTagsInDir(iTag, iPath, oTagsToPath)
        iTag.Children.each do |iChildTag|
          # Make sure the name only has valid characters
          lChildPath = "#{iPath}/#{get_valid_file_name(iChildTag.Name)}"
          require 'fileutils'
          FileUtils.mkdir_p(lChildPath)
          oTagsToPath[iChildTag] = lChildPath
          createTagsInDir(iChildTag, lChildPath, oTagsToPath)
        end
      end

      # Export a Shortcut in a directory
      #
      # Parameters::
      # * *iController* (_Controller_): The controller
      # * *iShortcut* (_Shortcut_): The Shortcut to export
      # * *iPath* (_String_): Directory in which we export the Shortcut
      def exportShortcut(iController, iShortcut, iPath)
        # Here we have to know how to export the different Shortcut types.
        # Maybe add a generic function to each Shortcut type ?
        lURLTypePlugin = nil
        iController.accessTypesPlugin('URL') do |iPlugin|
          lURLTypePlugin = iPlugin
        end
        case iShortcut.Type
        when lURLTypePlugin
          File.open("#{iPath}/#{get_valid_file_name(iShortcut.Metadata['title'])}.url", 'w') do |oFile|
            oFile << "[InternetShortcut]
URL=#{iShortcut.Content}
"
          end
        else
          log_err "Can't create a file for Shortcuts of type #{iShortcut.Type.pluginDescription[:PluginName]}. Need to adapt the Files plugin to this Shortcuts' type."
        end
      end

    end

  end

end