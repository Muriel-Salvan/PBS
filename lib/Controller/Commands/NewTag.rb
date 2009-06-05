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
          # Create an empty Tag that we will edit
          lNewTag = Tag.new('New Tag', nil, nil)
          # Now we edit lNewTag
          lEditTagDialog = EditTagDialog.new(lWindow, lNewTag)
          case lEditTagDialog.show_modal
          when Wx::ID_OK
            lNewName, lNewIcon = lEditTagDialog.getNewData
            # First check that a Tag like this does not exist already
            lNewID = lTag.getUniqueID + [lNewName]
            lAlreadyExistingTag = findTag(lNewID)
            if (lAlreadyExistingTag == nil)
              # OK, we can create it for real
              addNewTag(lTag, Tag.new(lNewName, lNewIcon, nil))
            else
              # Oups, already here
              puts "!!! A Tag named #{lNewName} already exists as a sub-Tag of #{lTag.Name}."
            end
          end
        end
      end

    end

  end

end
