#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class NewTag

      # Command that creates a new Tag.
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *tag* (_Tag_): Tag in which we create the new Tag (can be the Root Tag)
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        lTag = iParams[:tag]
        lParentTagName = nil
        if (lTag == ioController.RootTag)
          lParentTagName = 'Root'
        else
          lParentTagName = lTag.Name
        end
        ioController.undoableOperation("Create new Tag in #{lParentTagName}") do
          require 'pbs/Windows/EditTagDialog'
          showModal(EditTagDialog, lWindow, nil) do |iModalResult, iDialog|
            case iModalResult
            when Wx::ID_OK
              lNewName, lNewIcon = iDialog.getData
              ioController.createTag(lTag, lNewName, lNewIcon)
            end
          end
        end
      end

    end

  end

end
