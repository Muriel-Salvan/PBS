#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/OptionsDialog.rb'

module PBS

  module Commands

    class Setup

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
          :title => 'Setup',
          :description => 'Customize PBS',
          :bitmapName => 'Config.png',
          :commandID => Wx::ID_SETUP,
          :parameters => [
            :parentWindow
          ]
        }
      end

      # Command that launches the setup
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        # Display Options dialog
        showModal(OptionsDialog, lWindow, ioController.Options) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            lOldOptions = ioController.Options.clone
            # Set options of the dialog
            iDialog.getOptions.each do |iKey, iValue|
              ioController.Options[iKey] = iValue
            end
            ioController.notifyOptionsChanged(lOldOptions)
          end
        end
      end

    end

  end

end
