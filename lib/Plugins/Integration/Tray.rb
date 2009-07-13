#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Integration

    class TrayIcon < Wx::TaskBarIcon

      include Tools

      DEFAULT_ICON = Tools::loadBitmap('Icon32.png')

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      def initialize(iController)
        super()
        @Controller = iController
        # The current icon.
        # This is useful to keep track of it when replacing it: we need to first remove the current one.
        # Wx::Icon
        @CurrentIcon = nil
        # The Root Tag to display in the menu
        # Tag
        @RootTag = nil
      end

      # Method that adds sub-Tags of a given Tag to a menu
      # This method just creates hierarchical menus of Tags, ignoring Shortcuts
      #
      # Parameters:
      # * *iTag* (_Tag_): Tag containing sub-Tags to add to the menu
      # * *ioMenu* (<em>Wx::Menu</em>): Menu to add the Tag to
      # * *oTagsToMenu* (<em>map<Tag,Wx::Menu></em>): Correspondance between Tags and menu
      def addChildrenTagToMenu(iTag, ioMenu, oTagsToMenu)
        # Create children menus
        # First, create a quick index to sort them alphabetically
        # map< String, list< Tag > >
        lIndexedTags = {}
        iTag.Children.each do |iChildTag|
          lName = convertAccentsString(iChildTag.Name.upcase)
          if (lIndexedTags[lName] == nil)
            lIndexedTags[lName] = []
          end
          lIndexedTags[lName] << iChildTag
        end
        # Then create them
        lIndexedTags.keys.sort.each do |iChildName|
          lIndexedTags[iChildName].each do |iChildTag|
            # The sub menu of this Tag
            lTagMenu = Wx::Menu.new
            ioMenu.append_sub_menu(lTagMenu, iChildTag.Name)
            # Register it
            oTagsToMenu[iChildTag] = lTagMenu
            addChildrenTagToMenu(iChildTag, lTagMenu, oTagsToMenu)
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
        addChildrenTagToMenu(@RootTag, rMenu, lTagsToMenu)
        # And now instantiate Shortcuts
        # Create a quick index to sort them alphabetically
        # map< String, list< Shortcut > >
        lIndexedShortcuts = {}
        @Controller.ShortcutsList.each do |iShortcut|
          lName = convertAccentsString(iShortcut.Metadata['title'].upcase)
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
              # Create only 1 item in the root if we display the root Tag only
              if (@RootTag == @Controller.RootTag)
                lMenuItems[Wx::MenuItem.new(rMenu, Wx::ID_ANY)] = rMenu
              end
            else
              iShortcut.Tags.each do |iTag, iNil|
                if (@RootTag == iTag)
                  # This Shortcut must be put at the Root menu
                  lMenuItems[Wx::MenuItem.new(rMenu, Wx::ID_ANY)] = rMenu
                else
                  # Retrieve the corresponding menu, and create an item inside
                  lParentMenu = lTagsToMenu[iTag]
                  # Add it if the menu is to be displayed only (it can not be the case if we asked to display another Tag than the root one)
                  if (lParentMenu != nil)
                    lMenuItems[Wx::MenuItem.new(lParentMenu, Wx::ID_ANY)] = lParentMenu
                  end
                end
              end
            end
            # And now format each item the same way
            lMenuItems.each do |ioMenuItem, ioParentMenu|
              ioMenuItem.text = iShortcut.Metadata['title']
              ioMenuItem.help = iShortcut.getContentSummary
              ioMenuItem.bitmap = @Controller.getShortcutIcon(iShortcut)
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
      # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap of the icon (can be nil for the default one)
      # Return:
      # * <em>Wx::Icon</em>: Resulting icon
      def makeTrayIcon(iBitmap)
        lRealBitmap = iBitmap
        if (iBitmap == nil)
          lRealBitmap = DEFAULT_ICON
        end
        # Different platforms have different requirements for the taskbar icon size
        if Wx::PLATFORM == "WXMSW"
          if ((lRealBitmap.width != 16) or
              (lRealBitmap.height != 16))
            # Need to rescale
            lRealBitmap = Wx::Bitmap.new(lRealBitmap.convert_to_image.scale(16, 16))
          end
        elsif Wx::PLATFORM == "WXGTK"
          if ((lRealBitmap.width != 22) or
              (lRealBitmap.height != 22))
            # Need to rescale
            lRealBitmap = Wx::Bitmap.new(lRealBitmap.convert_to_image.scale(22, 22))
          end
        elsif Wx::PLATFORM == "WXMAC"
          # WXMAC can be any size up to 128x128
          lResize = false
          lNewWidth = lRealBitmap.width
          if (lRealBitmap.width > 128)
            lNewWidth = 128
            lResize = true
          end
          lNewHeight = lRealBitmap.height
          if (lRealBitmap.height > 128)
            lNewHeight = 128
            lResize = true
          end
          if (lResize)
            # Need to rescale
            lRealBitmap = Wx::Bitmap.new(lRealBitmap.convert_to_image.scale(lNewWidth, lNewHeight))
          end
        end
        rIcon = Wx::Icon.new
        rIcon.copy_from_bitmap(lRealBitmap)

        return rIcon
      end

      # Set the Tray icon from a bitmap
      # Resizes the bitmap if needed
      #
      # Parameters:
      # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap of the icon (can be nil for the default one)
      def setTrayIcon(iBitmap)
        if (@CurrentIcon != nil)
          remove_icon
        end
        @CurrentIcon = makeTrayIcon(iBitmap)
        set_icon(@CurrentIcon, 'PBS')
      end

      # Options specifics to this plugin have changed
      #
      # Parameters:
      # * *iNewOptions* (_Object_): The new options
      # * *iNewTag* (_Tag_): The new Tag to integrate
      # * *iOldOptions* (_Object_): The old options (can be nil during startup)
      # * *iOldTag* (_Tag_): The old Tag to integrate (can be nil during startup)
      def onPluginOptionsChanged(iNewOptions, iNewTag, iOldOptions, iOldTag)
        setTrayIcon(iNewOptions[:icon])
        @RootTag = iNewTag
      end

    end

    class ConfigPanel < Wx::Panel

      include Tools

      # An invalid icon
      DEFAULT_ICON = Tools::loadBitmap('Icon32.png')
      INVALID_ICON = Tools::loadBitmap('InvalidIcon.png')

      # Constructor
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      def initialize(iParent)
        super(iParent)

        # @Icon will be changed only if the icon is changed.
        # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
        @Icon = nil

        # Components
        lSTIcon = Wx::StaticText.new(self, Wx::ID_ANY, 'Icon')
        @BBIcon = Wx::BitmapButton.new(self, Wx::ID_ANY, Wx::Bitmap.new)

        # Sizers
        lMainSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lMainSizer.add_item([0,0], :proportion => 1)
        lMainSizer.add_item(lSTIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item([8,0], :proportion => 0)
        lMainSizer.add_item(@BBIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item([0,0], :proportion => 1)
        self.sizer = lMainSizer

        # Events
        evt_button(@BBIcon) do |iEvent|
          # display the icon chooser dialog
          showModal(ChooseIconDialog, self, @BBIcon.bitmap_label) do |iModalResult, iDialog|
            case iModalResult
            when Wx::ID_OK
              lNewIcon = iDialog.getSelectedBitmap
              if (lNewIcon != nil)
                @Icon = lNewIcon
                setBBIcon
              end
            end
          end
        end

      end

      # Set the BitmapButton icon, based on @Icon
      def setBBIcon
        lIconBitmap = @Icon
        if (lIconBitmap == nil)
          lIconBitmap = DEFAULT_ICON
        end
        if (lIconBitmap.is_ok)
          @BBIcon.bitmap_label = lIconBitmap
        else
          @BBIcon.bitmap_label = INVALID_ICON
        end
        @BBIcon.size = [ @BBIcon.bitmap_label.width + 4, @BBIcon.bitmap_label.height + 4 ]
      end

      # Create the options corresponding to this panel
      #
      # Return:
      # * _Object_: The corresponding options
      def getData
        return { :icon => @Icon }
      end

      # Set the panel's content from given options
      #
      # Parameters:
      # * *iOptions* (_Object_): The corresponding options
      def setData(iOptions)
        @Icon = iOptions[:icon]
        setBBIcon
      end

    end

    class Tray

      # Get the default options
      #
      # Return:
      # * _Object_: The default options (can be nil if none needed)
      def getDefaultOptions
        return {
          :icon => nil
        }
      end

      # Get the configuration panel
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # Return:
      # * <em>Wx::Panel</em>: The configuration panel, or nil if none needed
      def getConfigPanel(iParent)
        return ConfigPanel.new(iParent)
      end

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      def initialize(iController)
        @Controller = iController
      end

      # Create a new instance of the integration plugin
      #
      # Return:
      # * _Object_: The instance of this integration plugin
      def createNewInstance
        return TrayIcon.new(@Controller)
      end

      # Delete a previously created instance
      #
      # Parameters:
      # * *ioInstance* (_Object_): The instance created via createNewInstance that we now have to delete
      def deleteInstance(ioInstance)
        ioInstance.remove_icon
        ioInstance.destroy
      end

    end

  end

end
