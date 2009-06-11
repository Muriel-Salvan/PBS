#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/EditTagDialog.rb'

module PBS

  module Commands

    module NewTag

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdNewTag(iCommands)
        iCommands[ID_NEW_TAG] = {
          :title => 'New Tag',
          :help => 'Create a new Tag',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/NewTag.png"),
          :method => :cmdNewTag,
          :accelerator => nil
        }
      end

      # Command that creates a new Tag.
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *tag* (_Tag_): Tag in which we create the new Tag (can be the Root Tag)
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdNewTag(iParams)
        lWindow = iParams[:parentWindow]
        lTag = iParams[:tag]
        lParentTagName = nil
        if (lTag == @RootTag)
          lParentTagName = 'Root'
        else
          lParentTagName = lTag.Name
        end
        undoableOperation("Create new Tag in #{lParentTagName}") do
          showModal(EditTagDialog, lWindow, nil) do |iModalResult, iDialog|
            case iModalResult
            when Wx::ID_OK
              lNewName, lNewIcon = iDialog.getNewData
              createTag(lTag, lNewName, lNewIcon)
            end
          end
        end
      end

    end

  end

end
