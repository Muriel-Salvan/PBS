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

      # Method that adds a Tag to a menu
      # This method just creates hierarchical menus of Tags, ignoring Shortcuts
      #
      # Parameters:
      # * *iTag* (_Tag_): Tag to add to the menu
      # * *ioMenu* (<em>Wx::Menu</em>): Menu to add the Tag to
      # * *oTagsToMenu* (<em>map<Tag,Wx::Menu></em>): Correspondance between Tags and menu
      def addTagToMenu(iTag, ioMenu, oTagsToMenu)
        # The sub menu of this Tag
        lTagMenu = Wx::Menu.new
        ioMenu.append_sub_menu(lTagMenu, iTag.Name)
        # Register it
        oTagsToMenu[iTag] = lTagMenu
        # Create children menus
        # First, create a quick index to sort them alphabetically
        # map< String, list< Tag > >
        lIndexedTags = {}
        iTag.Children.each do |iChildTag|
          if (lIndexedTags[iChildTag.Name] == nil)
            lIndexedTags[iChildTag.Name] = []
          end
          lIndexedTags[iChildTag.Name] << iChildTag
        end
        # Then create them
        lIndexedTags.keys.sort.each do |iChildName|
          lIndexedTags[iChildName].each do |iChildTag|
            addTagToMenu(iChildTag, lTagMenu, oTagsToMenu)
          end
        end
      end

      # Method called when invoking the menu
      #
      # Return:
      # * <em>Wx::Menu</em>: The menu to display
      def create_popup_menu
        # We have to create the menu each time, as WxRuby then destroys it.
        # If we try to reuse it, we'll get into some ObjectPreviouslyDeleted exceptions when invoking the menu a second time.
        rMenu = Wx::Menu.new

        # Parse all Tags
        # Keep a correspondance between each Tag and the corresponding menu, to add Shortcuts after
        # map< Tag, Wx::Menu >
        lTagsToMenu = {}
        @Controller.RootTag.Children.each do |iTag|
          addTagToMenu(iTag, rMenu, lTagsToMenu)
        end
        # And now instantiate Shortcuts
        # Create a quick index to sort them alphabetically
        # map< String, list< Shortcut > >
        lIndexedShortcuts = {}
        @Controller.ShortcutsList.each do |iShortcut|
          lName = iShortcut.Metadata['title']
          if (lIndexedShortcuts[lName] == nil)
            lIndexedShortcuts[lName] = []
          end
          lIndexedShortcuts[lName] << iShortcut
        end
        # then create them
        lIndexedShortcuts.keys.sort.each do |iName|
          lIndexedShortcuts[iName].each do |iShortcut|
            # The list of menu items instantiated for this Shortcut, with the corresponding parent menu
            # map< Wx::MenuItem, Wx::Menu >
            lMenuItems = {}
            if (iShortcut.Tags.empty?)
              # Create only 1 item in the root
              lMenuItems[Wx::MenuItem.new(rMenu, Wx::ID_ANY)] = rMenu
            else
              iShortcut.Tags.each do |iTag, iNil|
                # Retrieve the corresponding menu, and create an item inside
                lParentMenu = lTagsToMenu[iTag]
                lMenuItems[Wx::MenuItem.new(lParentMenu, Wx::ID_ANY)] = lParentMenu
              end
            end
            # And now format each item the same way
            lMenuItems.each do |ioMenuItem, ioParentMenu|
              ioMenuItem.text = iShortcut.Metadata['title']
              ioMenuItem.help = iShortcut.getContentSummary
              ioMenuItem.bitmap = iShortcut.getIcon
              # Insert it
              ioParentMenu.append_item(ioMenuItem)
              # Set its event
              evt_menu(ioMenuItem) do |iEvent|
                # We run the Shortcut
                iShortcut.run
              end
            end
          end
        end

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
