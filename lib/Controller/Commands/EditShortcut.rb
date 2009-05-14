#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/EditShortcutDialog.rb'

module PBS

  module Commands

    module EditShortcut

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdEditShortcut(iCommands)
        iCommands[ID_EDIT_SHORTCUT] = {
          :title => 'Edit Shortcut',
          :help => 'Edit the selected Shortcut\'s parameters',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdEditShortcut,
          :accelerator => nil
        }
      end

      # Command that edits a Shortcut.
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      # ** *shortcut* (_Shortcut_): The Shortcut to edit
      def cmdEditShortcut(iParams)
        lWindow = iParams[:parentWindow]
        lSC = iParams[:shortcut]
        undoableOperation("Edit Shortcut #{lSC.Metadata['title']}") do
          # Now we edit lSelectedSC
          lEditSCDialog = EditShortcutDialog.new(lWindow, lSC, @RootTag)
          case lEditSCDialog.show_modal
          when Wx::ID_OK
            lNewContent, lNewMetadata, lNewTags = lEditSCDialog.getNewData
            lModified = ((lSC.Content != lNewContent) or
                         (lSC.Metadata != lNewMetadata) or
                         (lSC.Tags != lNewTags))
            if (lModified)
              modifyShortcut(lSC, lNewContent, lNewMetadata, lNewTags)
              setCurrentFileModified
            end
          end
        end
      end

    end

  end

end
