#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/EditTagDialog.rb'

module PBS

  module Commands

    class NewTag

      include Tools

      # Give the description of this plugin
      #
      # Return:
      # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
      # ** :title (_String_): Name of the plugin
      # ** :description (_String_): Quick description
      # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
      # # Specific parameters to Command plugins:
      # ** :commandID (_Integer_): The command ID
      # ** :accelerator (<em>[Integer,Integer]</em>): The accelerator (modifier and key)
      # ** :parameters (<em>list<Symbol></em>): The list of symbols that GUIs have to provide to the execute method
      def pluginInfo
        return {
          :title => 'New Tag',
          :description => 'Create a new Tag',
          :bitmapName => 'NewTag.png',
          :commandID => ID_NEW_TAG,
          :parameters => [
            :parentWindow,
            :tag
          ]
        }
      end

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
