#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module ShortcutCommands

    class FillMetadata

      # Command that gives a default icon to a Shortcut
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *ioShortcut* (_Shortcut_): The Shortcut for which we called this command
      def execute(ioController, ioShortcut)
        ioController.undoableOperation("Fill metadata for #{ioShortcut.Metadata['title']}") do
          ioController.updateShortcut(
            ioShortcut,
            ioShortcut.Content,
            ioShortcut.Type.getMetadataFromContent(ioShortcut.Content),
            ioShortcut.Tags
          )
        end
      end

    end

  end

end
