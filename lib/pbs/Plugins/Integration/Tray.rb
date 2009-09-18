#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Integration

    # The list of sizes corresponding to each slider step
    ICON_SIZES = [
      8,
      16,
      24,
      32,
      48,
      64,
      72
    ]

    class TrayIcon < Wx::TaskBarIcon

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
        # The size of icons in the menu and sub-menus (in units of the slider, not pixels)
        # Integer
        @SizeMenu = nil
        @SizeSubMenu = nil
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

        # First, add a PBS submenu
        lPBSMenu = Wx::Menu.new
        lIntPluginsSubMenu = Wx::Menu.new
        # For each integration plugin, add a menu item
        @Controller.getIntegrationPlugins.each do |iPluginName, iPluginInfo|
          @Controller.addMenuCommand(self, lIntPluginsSubMenu, ID_INTEGRATION_INSTANCE_BASE + iPluginInfo[:PluginIndex])
        end
        lPBSMenu.append_sub_menu(lIntPluginsSubMenu, 'Instantiate a new view')
        lPBSMenu.append_separator
        @Controller.addMenuCommand(self, lPBSMenu, Wx::ID_SETUP) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => nil
          )
        end
        lPBSMenu.append_separator
        @Controller.addMenuCommand(self, lPBSMenu, Wx::ID_CLOSE) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :instancesToClose => [ self ]
          )
        end
        @Controller.addMenuCommand(self, lPBSMenu, Wx::ID_EXIT) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => nil
          )
        end
        rMenu.append_sub_menu(lPBSMenu, 'PBS')
        rMenu.append_separator

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
              # If the parent menu is the root menu, we need to size differently than for sub-menus
              lDesiredSize = nil
              if (ioParentMenu == rMenu)
                lDesiredSize = ICON_SIZES[@SizeMenu]
              else
                lDesiredSize = ICON_SIZES[@SizeSubMenu]
              end
              ioMenuItem.bitmap = getResizedBitmap(@Controller.getShortcutIcon(iShortcut), lDesiredSize, lDesiredSize)
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
          lRealBitmap = getGraphic('Icon32.png')
        end
        # Different platforms have different requirements for the taskbar icon size
        if Wx::PLATFORM == "WXMSW"
          lRealBitmap = getResizedBitmap(lRealBitmap, 16, 16)
        elsif Wx::PLATFORM == "WXGTK"
          lRealBitmap = getResizedBitmap(lRealBitmap, 22, 22)
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
      # * *iTitle* (_String_): Title to give to this icon (appears as the hint)
      def setTrayIcon(iBitmap, iTitle)
        if (@CurrentIcon != nil)
          remove_icon
        end
        @CurrentIcon = makeTrayIcon(iBitmap)
        set_icon(@CurrentIcon, iTitle)
      end

      # Options specifics to this plugin have changed
      #
      # Parameters:
      # * *iNewOptions* (_Object_): The new options
      # * *iNewTag* (_Tag_): The new Tag to integrate
      # * *iOldOptions* (_Object_): The old options (can be nil during startup)
      # * *iOldTag* (_Tag_): The old Tag to integrate (can be nil during startup)
      def onPluginOptionsChanged(iNewOptions, iNewTag, iOldOptions, iOldTag)
        setTrayIcon(iNewOptions[:icon], iNewTag.Name)
        @RootTag = iNewTag
        @SizeMenu = iNewOptions[:sizeMenu]
        @SizeSubMenu = iNewOptions[:sizeSubMenu]
      end

    end

    class ConfigPanel < Wx::Panel

      # Constructor
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window (can be called to get the current Tag to integrate)
      # * *iController* (_Controller_): The controller
      def initialize(iParent, iController)
        super(iParent)

        # TODO (WxRuby): Bug correction
        # Register this Event as otherwise dragging thumbs of sliders generate tons of warnings. Bug ?
        Wx::EvtHandler::EVENT_TYPE_CLASS_MAP[10105] = Wx::Event

        # @Icon will be changed only if the icon is changed.
        # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
        @Icon = nil

        # Cache of the icons
        # map< Integer, Wx::Bitmap >
        @CacheExampleIcons = {}

        # Components
        lSTIcon = Wx::StaticText.new(self, Wx::ID_ANY, 'Icon')
        @BBIcon = Wx::BitmapButton.new(self, Wx::ID_ANY, Wx::Bitmap.new)
        lBIconFromTag = Wx::Button.new(self, Wx::ID_ANY, '<- from Tag')
        lSTSize1 = Wx::StaticText.new(self, Wx::ID_ANY, 'Menus icons sizes')
        @SSize1 = Wx::Slider.new(self, Wx::ID_ANY, 0, 0, ICON_SIZES.size-1,
          :style => Wx::SL_VERTICAL|Wx::SL_AUTOTICKS|Wx::SL_BOTTOM)
        @SBExampleIcon1 = Wx::StaticBitmap.new(self, Wx::ID_ANY, Wx::Bitmap.new)
        lSTSize2 = Wx::StaticText.new(self, Wx::ID_ANY, 'Sub-Menus icons sizes')
        @SSize2 = Wx::Slider.new(self, Wx::ID_ANY, 0, 0, ICON_SIZES.size-1,
          :style => Wx::SL_VERTICAL|Wx::SL_AUTOTICKS)
        @SBExampleIcon2 = Wx::StaticBitmap.new(self, Wx::ID_ANY, Wx::Bitmap.new)

        # Sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item([0,0], :proportion => 1)

        lIconsButtonsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lIconsButtonsSizer.add_item(lSTIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lIconsButtonsSizer.add_item([8,0], :proportion => 0)
        lIconsButtonsSizer.add_item(@BBIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lIconsButtonsSizer.add_item(lBIconFromTag, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

        lMainSizer.add_item(lIconsButtonsSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item([0,8], :proportion => 0)

        lSizesSizer =  Wx::BoxSizer.new(Wx::HORIZONTAL)

        lSizes1Sizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lSizes1Sizer.add_item(lSTSize1, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizes1BottomSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lSizes1BottomSizer.add_item(@SSize1, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizes1BottomSizer.add_item(@SBExampleIcon1, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizes1Sizer.add_item(lSizes1BottomSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

        lSizesSizer.add_item(lSizes1Sizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizesSizer.add_item([8,0], :proportion => 0)

        lSizes2Sizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lSizes2Sizer.add_item(lSTSize2, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizes2BottomSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lSizes2BottomSizer.add_item(@SSize2, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizes2BottomSizer.add_item(@SBExampleIcon2, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lSizes2Sizer.add_item(lSizes2BottomSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

        lSizesSizer.add_item(lSizes2Sizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

        lMainSizer.add_item(lSizesSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
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
                setBitmapIcons
              end
            end
          end
        end
        @SSize1.evt_scroll_thumbtrack do |iEvent|
          setBitmapIcons
        end
        @SSize1.evt_scroll_pagedown do |iEvent|
          @SSize1.value += 1
          setBitmapIcons
        end
        @SSize1.evt_scroll_pageup do |iEvent|
          @SSize1.value -= 1
          setBitmapIcons
        end
        @SSize2.evt_scroll_thumbtrack do |iEvent|
          setBitmapIcons
        end
        @SSize2.evt_scroll_pagedown do |iEvent|
          @SSize2.value += 1
          setBitmapIcons
        end
        @SSize2.evt_scroll_pageup do |iEvent|
          @SSize2.value -= 1
          setBitmapIcons
        end
        evt_button(lBIconFromTag) do |iEvent|
          # Take the Tag's icon for the icon
          lTag = iParent.getIntegratedTag
          if (lTag == nil)
            @Icon = nil
          else
            @Icon = iController.getTagIcon(lTag)
          end
          setBitmapIcons
        end

      end

      # Set the Bitmap icons, based on @Icon and the sizes
      def setBitmapIcons
        # The BitmapButton
        lIconBitmap = @Icon
        if (lIconBitmap == nil)
          lIconBitmap = getGraphic('Icon32.png')
        end
        if (lIconBitmap.is_ok)
          @BBIcon.bitmap_label = lIconBitmap
        else
          @BBIcon.bitmap_label = getGraphic('InvalidIcon.png')
        end
        @BBIcon.size = [ @BBIcon.bitmap_label.width + 4, @BBIcon.bitmap_label.height + 4 ]
        # The example icons
        if (@CacheExampleIcons[@SSize1.value] == nil)
          # Load the icon
          @CacheExampleIcons[@SSize1.value] = getResizedBitmap(getGraphic('Icon32.png'), ICON_SIZES[@SSize1.value], ICON_SIZES[@SSize1.value])
        end
        @SBExampleIcon1.bitmap = @CacheExampleIcons[@SSize1.value]
        if (@CacheExampleIcons[@SSize2.value] == nil)
          # Load the icon
          @CacheExampleIcons[@SSize2.value] = getResizedBitmap(getGraphic('Icon32.png'), ICON_SIZES[@SSize2.value], ICON_SIZES[@SSize2.value])
        end
        @SBExampleIcon2.bitmap = @CacheExampleIcons[@SSize2.value]
        refresh
      end

      # Create the options corresponding to this panel
      #
      # Return:
      # * _Object_: The corresponding options
      def getData
        return {
          :icon => @Icon,
          :sizeMenu => @SSize1.value,
          :sizeSubMenu => @SSize2.value
        }
      end

      # Set the panel's content from given options
      #
      # Parameters:
      # * *iOptions* (_Object_): The corresponding options
      def setData(iOptions)
        @Icon = iOptions[:icon]
        @SSize1.value = iOptions[:sizeMenu]
        @SSize2.value = iOptions[:sizeSubMenu]
        setBitmapIcons
      end

    end

    class Tray

      # Get the default options
      #
      # Return:
      # * _Object_: The default options (can be nil if none needed)
      def getDefaultOptions
        return {
          :icon => nil,
          :sizeMenu => 2,
          :sizeSubMenu => 1
        }
      end

      # Get the configuration panel
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iController* (_Controller_): The controller
      # Return:
      # * <em>Wx::Panel</em>: The configuration panel, or nil if none needed
      def getConfigPanel(iParent, iController)
        return ConfigPanel.new(iParent, iController)
      end

      # Create a new instance of the integration plugin
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # Return:
      # * _Object_: The instance of this integration plugin
      def createNewInstance(iController)
        return TrayIcon.new(iController)
      end

      # Delete a previously created instance
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *ioInstance* (_Object_): The instance created via createNewInstance that we now have to delete
      def deleteInstance(iController, ioInstance)
        ioInstance.remove_icon
        ioInstance.destroy
      end

    end

  end

end
