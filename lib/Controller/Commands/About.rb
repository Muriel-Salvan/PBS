#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/AboutDialog.rb'

module PBS

  module Commands

    module About

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdAbout(iCommands)
        iCommands[Wx::ID_ABOUT] = {
          :title => 'About',
          :help => 'Give information about PBS',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/MiniIcon.png"),
          :method => :cmdAbout,
          :accelerator => nil
        }
      end

      # Command that edits an item (Shortcut/Tag).
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def cmdAbout(iParams)
        lWindow = iParams[:parentWindow]
        showModal(AboutDialog, lWindow) do |iModalResult, iDialog|
          # Nothing to do
        end
      end

    end

  end

end
