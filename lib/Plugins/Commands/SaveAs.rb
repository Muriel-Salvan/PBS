#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class SaveAs

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
          :title => 'Save As',
          :description => 'Save current Shortcuts in a new PBS file',
          :bitmapName => 'SaveAs.png',
          :commandID => Wx::ID_SAVEAS,
          :parameters => [
            :parentWindow
          ]
        }
      end

      # Command that saves the file in a new name
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Display Save dialog
        showModal(Wx::FileDialog, lWindow,
          :message => 'Save file',
          :style => Wx::FD_SAVE|Wx::FD_OVERWRITE_PROMPT,
          :wildcard => 'PBS Shortcuts (*.pbss)|*.pbss'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            ioController.undoableOperation("Save file #{File.basename(iDialog.path)[0..-6]}") do
              # Perform save
              saveData(ioController, iDialog.path)
              ioController.changeCurrentFileName(iDialog.path)
            end
          end
        end
      end

    end

  end

end
