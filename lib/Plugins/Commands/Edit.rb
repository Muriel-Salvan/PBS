#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/EditShortcutDialog.rb'
require 'Windows/EditTagDialog.rb'

module PBS

  module Commands

    class Edit

      include Tools

      # Command that edits an item (Shortcut/Tag).
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      # ** *objectID* (_Integer_): The ID of the object to edit
      # ** *object* (_Object_): The object to edit
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        lObjectID = iParams[:objectID]
        lObject = iParams[:object]
        case lObjectID
        when ID_TAG
          ioController.undoableOperation("Edit Tag #{lObject.Name}") do
            # Now we edit lObject
            showModal(EditTagDialog, lWindow, lObject) do |iModalResult, iDialog|
              case iModalResult
              when Wx::ID_OK
                lNewName, lNewIcon = iDialog.getData
                ioController.updateTag(lObject, lNewName, lNewIcon, lObject.Children)
              end
            end
          end
        when ID_SHORTCUT
          ioController.undoableOperation("Edit Shortcut #{lObject.Metadata['title']}") do
            # Now we edit lObject
            showModal(EditShortcutDialog, lWindow, lObject, ioController.RootTag, ioController) do |iModalResult, iDialog|
              case iModalResult
              when Wx::ID_OK
                lNewContent, lNewMetadata, lNewTags = iDialog.getData
                ioController.updateShortcut(lObject, lNewContent, lNewMetadata, lNewTags)
              end
            end
          end
        else
          logBug "Unable to edit object of ID #{lObjectID}."
        end
      end

    end

  end

end
