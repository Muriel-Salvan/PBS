#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Open

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
          :title => 'Open',
          :description => 'Open a PBS file',
          :bitmapName => 'Open.png',
          :commandID => Wx::ID_OPEN,
          :accelerator => [ Wx::MOD_CMD, 'o'[0] ],
          :parameters => [
            :parentWindow
          ]
        }
      end

      # Command that opens a file
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Display Open dialog
        showModal(Wx::FileDialog, lWindow,
          :message => 'Open file',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            if (ioController.checkSavedWorkAndScratch(lWindow))
              ioController.undoableOperation("Open file #{File.basename(iDialog.path)[0..-6]}") do
                # Really perform the open
                openData(ioController, iDialog.path)
                ioController.changeCurrentFileName(iDialog.path)
              end
            end
          end
        end
      end

    end

  end

end
