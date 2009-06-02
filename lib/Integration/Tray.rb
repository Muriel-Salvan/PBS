#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Integration

    class TrayIcon < Wx::TaskBarIcon

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      def initialize(iController)
        super()
        @Controller = iController

        # The icon
        set_icon(makeIcon("#{$PBSRootDir}/Graphics/Icon.png"), 'PBS')
      end

      # Method called when invoking the menu
      #
      # Return:
      # * <em>Wx::Menu</em>: The menu to display
      def create_popup_menu
        rMenu = Wx::Menu.new

        # TODO: Create the menu correctly
        @Controller.addMenuCommand(self, rMenu, Wx::ID_EDIT) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => nil,
            :objectID => ID_SHORTCUT,
            :object => @Controller.ShortcutsList[0]
          )
        end
        rMenu.append_separator

        return rMenu
      end

      # Create an icon that fits the Tray
      #
      # Parameters:
      # * *iFileName* (_String_): Name of the file containing the icon
      # Return:
      # * <em>Wx::Icon</em>: Resulting icon
      def makeIcon(iFileName)
        # Different platforms have different requirements for the taskbar icon size
        lImg = Wx::Image.new(iFileName)
        if Wx::PLATFORM == "WXMSW"
          lImg = lImg.scale(16, 16)
        elsif Wx::PLATFORM == "WXGTK"
          lImg = lImg.scale(22, 22)
        end
        # WXMAC can be any size up to 128x128, so don't scale
        rIcon = Wx::Icon.new
        rIcon.copy_from_bitmap(Wx::Bitmap.new(lImg))

        return rIcon
      end

    end

    class Tray

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      def initialize(iController)
        @Controller = iController
      end

      # Initialize the integration plugin
      def onInit
        @Icon = TrayIcon.new(@Controller)
      end

      # Finalize the integration plugin
      def onExit
        @Icon.remove_icon
        @Icon.destroy
      end

    end

  end

end
