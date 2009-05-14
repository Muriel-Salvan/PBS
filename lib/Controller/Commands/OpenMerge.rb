#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module OpenMerge

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdOpenMerge(iCommands)
        iCommands[ID_OPEN_MERGE] = {
          :title => 'Open and Merge',
          :help => 'Open a PBS file and merge it with existing',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdOpenMerge,
          :accelerator => nil
        }
      end

      # Command that opens a file and merges its content with the current project
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdOpenMerge(iParams)
        lWindow = iParams[:parentWindow]
        # Display Open dialog
        lOpenDialog = Wx::FileDialog.new(lWindow,
          :message => 'Open file for merge',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        )
        case lOpenDialog.show_modal
        when Wx::ID_OK
          undoableOperation("Merge file #{File.basename(lOpenDialog.path)[0..-6]}") do
            # Really perform the open
            lNewRootTag, lNewShortcutsList = openData(@TypesPlugins, lOpenDialog.path)
            # Merge with current data
            mergeTags(@RootTag, lNewRootTag)
            mergeShortcuts(lNewShortcutsList)
            setCurrentFileModified
          end
        end
      end

    end

  end

end