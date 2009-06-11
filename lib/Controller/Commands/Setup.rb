#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/OptionsDialog.rb'

module PBS

  module Commands

    module Setup

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdSetup(iCommands)
        iCommands[Wx::ID_SETUP] = {
          :title => 'Setup',
          :help => 'Customize PBS',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Config.png"),
          :method => :cmdSetup,
          :accelerator => nil
        }
      end

      # Command that launches the setup
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdSetup(iParams)
        lWindow = iParams[:parentWindow]
        # Display Options dialog
        showModal(OptionsDialog, lWindow, @Options) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            lOldOptions = @Options.clone
            @Options = iDialog.getOptions
            notifyOptionsChanged(lOldOptions)
          end
        end
      end

    end

  end

end
