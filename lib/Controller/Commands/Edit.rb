#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/EditShortcutDialog.rb'

module PBS

  module Commands

    module Edit

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdEdit(iCommands)
        iCommands[Wx::ID_EDIT] = {
          :title => 'Edit',
          :help => 'Edit the selection',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdEdit,
          :accelerator => nil
        }
      end

      # Command that edits an item (Shortcut/Tag).
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      # ** *objectID* (_Integer_): The ID of the object to edit
      # ** *object* (_Object_): The object to edit
      def cmdEdit(iParams)
        lWindow = iParams[:parentWindow]
        lObjectID = iParams[:objectID]
        lObject = iParams[:object]
        case lObjectID
        when ID_TAG
          # TODO
        when ID_SHORTCUT
          undoableOperation("Edit Shortcut #{lObject.Metadata['title']}") do
            # Now we edit lSelectedSC
            lEditSCDialog = EditShortcutDialog.new(lWindow, lObject, @RootTag)
            case lEditSCDialog.show_modal
            when Wx::ID_OK
              lNewContent, lNewMetadata, lNewTags = lEditSCDialog.getNewData
              lModified = ((lObject.Content != lNewContent) or
                           (lObject.Metadata != lNewMetadata) or
                           (lObject.Tags != lNewTags))
              if (lModified)
                modifyShortcut(lObject, lNewContent, lNewMetadata, lNewTags)
                setCurrentFileModified
              end
            end
          end
        else
          puts "!!! Unable to edit object of ID #{lObjectID}. Bug ?"
        end
      end

    end

  end

end
