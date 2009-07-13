#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/SelectTagDialog.rb'

module PBS

  # Panel displaying options about integration plugins
  class IntegrationPanel < Wx::Panel

    # The list view displaying instantiated plugins
    class InstantiatedPluginsListCtrl < Wx::ListCtrl

      include Tools

      IMAGE_CHECKBOX_CHECKED = Tools::loadBitmap('Checkbox_Checked.png')
      IMAGE_CHECKBOX_UNCHECKED = Tools::loadBitmap('Checkbox_UnChecked.png')

      # Constructor
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iController* (_Controller_): The controller, for plugins info
      def initialize(iParent, iController)
        super(iParent, Wx::ID_ANY,
          :style => Wx::LC_REPORT|Wx::LC_SINGLE_SEL|Wx::LC_VIRTUAL
        )
        set_item_count(0)
        insert_column(0, 'Active')
        insert_column(1, 'Type')
        insert_column(2, 'Tag')

        @Controller = iController
        # The displayed list info, stores the same info as PluginsOptions, but ensures that the order will not be altered.
        # list< [ String, Tag, Boolean, Object, Object ] >
        @DisplayedList = nil

        # Create the image list
        @ImageList = Wx::ImageList.new(16, 16)
        self.set_image_list(@ImageList, Wx::IMAGE_LIST_SMALL)
        # Make this image list driven by a manager
        @ImageListManager = Tools::ImageListManager.new(@ImageList, 16, 16)

      end

      # Set the list based on given options
      #
      # Parameters:
      # * *iDisplayedList* (<em>list<[String,Tag,Boolean,Object,Object]></em>): The list of plugins
      def setOptions(iDisplayedList)
        @DisplayedList = iDisplayedList
        set_item_count(@DisplayedList.size)
        # Refresh everything
        refresh_items(0, item_count)
        # Rearrange columns widths
        set_column_width(0, 20)
        set_column_width(1, Wx::LIST_AUTOSIZE)
        set_column_width(2, Wx::LIST_AUTOSIZE)
        # Compute minimal size
        self.min_size = [ [ column_width(0) + column_width(1) + column_width(2) + 8, 200 ].min, 0 ]
        # Resize
        lOldSize = self.parent.size
        self.parent.fit
        self.parent.size = lOldSize
      end

      # Callback that returns item text
      #
      # Parameters:
      # * *iIdxItem* (_Integer_): Item's index
      # * *iIdxColumn* (_Integer_): Column's index
      # Return:
      # * _String_: The text
      def on_get_item_text(iIdxItem, iIdxColumn)
        rText = ''

        case iIdxColumn
        when 0
          rText = ''
        when 1
          rText = @Controller.IntegrationPlugins[@DisplayedList[iIdxItem][0]][:title]
        when 2
          rText = @DisplayedList[iIdxItem][1].Name
        else
          logBug "Unknown column ID #{iIdxColumn} for text list display."
        end

        return rText
      end

      # Callback that returns item image
      #
      # Parameters:
      # * *iIdxItem* (_Integer_): Item's index
      # * *iIdxColumn* (_Integer_): Column's index
      # Return:
      # * _Integer_: The image index
      def on_get_item_column_image(iIdxItem, iIdxColumn)
        rIdxImage = ''

        case iIdxColumn
        when 0
          rIdxImage = @ImageListManager.getImageIndex(@DisplayedList[iIdxItem][2]) do
            if (@DisplayedList[iIdxItem][2])
              rImage = IMAGE_CHECKBOX_CHECKED
            else
              rImage = IMAGE_CHECKBOX_UNCHECKED
            end
            next rImage
          end
        when 1
          rIdxImage = @ImageListManager.getImageIndex( [
            Wx::Bitmap,
            @Controller.IntegrationPlugins[@DisplayedList[iIdxItem][0]][:bitmapName]
          ] ) do
            next @Controller.IntegrationPlugins[@DisplayedList[iIdxItem][0]][:bitmap]
          end
        when 2
          rIdxImage = @ImageListManager.getImageIndex( [
            Tag,
            @DisplayedList[iIdxItem][1]
          ] ) do
            next @Controller.getTagIcon(@DisplayedList[iIdxItem][1])
          end
        else
          logBug "Unknown column ID #{iIdxColumn} for image list display."
        end

        return rIdxImage
      end

    end

    # Panel that displays options for a given instantiated integration plugin
    class InstantiatedPluginOptionsPanel < Wx::Panel

      include Tools

      BITMAP_SELECTTAG = Tools::loadBitmap('Tree.png')

      # Constructor
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iController* (_Controller_): The controller
      # * *ioDisplayedItem* (<em>[String,Tag,Boolean,Object]</em>): The item info to display
      # * *ioNotifier* (_Object_): Object to be notified when modifications occur
      # * *iItemID* (_Integer_): The item's ID being displayed in this panel
      def initialize(iParent, iController, ioDisplayedItem, ioNotifier, iItemID)
        super(iParent)

        # Components
        @ConfigPanel = iController.IntegrationPlugins[ioDisplayedItem[0]][:plugin].getConfigPanel(self)
        @ConfigPanel.setData(ioDisplayedItem[3])
        lSTTag = Wx::StaticText.new(self, Wx::ID_ANY, 'Tag:')
        lSTTagName = Wx::StaticText.new(self, Wx::ID_ANY, ioDisplayedItem[1].Name)
        lBBSelectTag = Wx::BitmapButton.new(self, Wx::ID_ANY, BITMAP_SELECTTAG)
        lCBActive = Wx::CheckBox.new(self, Wx::ID_ANY, 'Active')
        lCBActive.value = ioDisplayedItem[2]
        lBDelete = Wx::Button.new(self, Wx::ID_ANY, 'Delete')

        # Sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item(@ConfigPanel, :flag => Wx::GROW, :proportion => 1)

        lTagSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lTagSizer.add_item([8, 0], :proportion => 0)
        lTagSizer.add_item(lSTTag, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lTagSizer.add_item([8, 0], :proportion => 0)
        lTagSizer.add_item(lSTTagName, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lTagSizer.add_item([8, 0], :proportion => 0)
        lTagSizer.add_item(lBBSelectTag, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lTagSizer.add_item([0, 0], :proportion => 1)

        lMainSizer.add_item(lTagSizer, :flag => Wx::ALIGN_LEFT, :proportion => 0)

        lBottomSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lBottomSizer.add_item(lCBActive, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lBottomSizer.add_item([0, 0], :proportion => 1)
        lBottomSizer.add_item(lBDelete, :flag => Wx::ALIGN_CENTER, :proportion => 0)

        lMainSizer.add_item(lBottomSizer, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)

        self.sizer = lMainSizer
        self.fit

        # Events
        evt_checkbox(lCBActive) do |iEvent|
          ioDisplayedItem[2] = lCBActive.value
          ioNotifier.refreshList
        end
        evt_button(lBBSelectTag) do |iEvent|
          showModal(SelectTagDialog, self, iController.RootTag, iController) do |iModalResult, iDialog|
            if (iModalResult == Wx::ID_OK)
              lTag = iDialog.getSelectedTag
              if (lTag != nil)
                # Update display
                lSTTagName.label = lTag.Name
                # Fit
                lOldSize = self.size
                self.fit
                self.size = lOldSize
                # Modify underlying data
                ioDisplayedItem[1] = lTag
                # Notify for modification
                ioNotifier.refreshList
              end
            end
          end
        end
        evt_button(lBDelete) do |iEvent|
          # Delete this instance
          ioNotifier.deleteItem(iItemID)
        end
        
      end

      # Get the options from the plugin specifics components
      #
      # Return:
      # * _Object_: The options
      def getOptions
        return @ConfigPanel.getData
      end

    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent window
    # * *iController* (_Controller_): The controller, used to get plugins specific data
    def initialize(iParent, iController)
      super(iParent)

      @Controller = iController
      # The panel that will be instantiated dynamically to show plugins options
      @PluginOptionsPanel = nil
      # The corresponding displayed item info
      # [ String, Tag, Boolean, Object, Object ]
      @DisplayedItemInfo = nil

      # The context menu, created once on demand
      @NewMenu = nil

      # The displayed list info, stores the same info as PluginsOptions, but ensures that the order will not be altered.
      # list< [ String, Tag, Boolean, Object, Object ] >
      @DisplayedList = []

      # Components
      @IPLC = InstantiatedPluginsListCtrl.new(self, @Controller)
      lBAddNew = Wx::Button.new(self, Wx::ID_ANY, 'Add new')

      # Sizers
      lMainSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)

      lLeftSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lLeftSizer.add_item(@IPLC, :flag => Wx::GROW, :proportion => 1)
      lLeftSizer.add_item(lBAddNew, :flag => Wx::ALIGN_LEFT, :proportion => 0)

      lMainSizer.add_item(lLeftSizer, :flag => Wx::GROW|Wx::ALL, :border => 2, :proportion => 0)
      self.sizer = lMainSizer
      self.fit

      # Events
      evt_list_item_selected(@IPLC) do |iEvent|
        lIdxItem = iEvent.index
        # Instantiate a config panel for this type
        resetOptionsPanel
        @DisplayedItemInfo = @DisplayedList[lIdxItem]
        @PluginOptionsPanel = InstantiatedPluginOptionsPanel.new(self, @Controller, @DisplayedItemInfo, self, lIdxItem)
        # Fit everything in sizers
        lMainSizer.add_item(@PluginOptionsPanel, :flag => Wx::GROW, :proportion => 1)
        lOldSize = self.size
        self.fit
        self.size = lOldSize
      end
      evt_button(lBAddNew) do |iEvent|
        # Create a menu that proposes to create a new integration plugin
        if (@NewMenu == nil)
          computeNewMenu
        end
        popup_menu(@NewMenu)
      end

    end

    # Computes the menu to create new plugin instances
    # It is assumed that it is not created yet
    def computeNewMenu
      @NewMenu = Wx::Menu.new
      @Controller.IntegrationPlugins.each do |iPluginID, iPluginInfo|
        lNewMenuItem = Wx::MenuItem.new(@NewMenu, Wx::ID_ANY, iPluginInfo[:title])
        lNewMenuItem.bitmap = iPluginInfo[:bitmap]
        @NewMenu.append_item(lNewMenuItem)
        # The event
        evt_menu(lNewMenuItem) do |iEvent|
          @DisplayedList << [
            iPluginID,
            @Controller.RootTag,
            true,
            @Controller.IntegrationPlugins[iPluginID][:plugin].getDefaultOptions,
            nil
          ]
          refreshList
        end
      end
    end

    # Refreshes the components after a visible change on @DisplayedList
    def refreshList
      @IPLC.setOptions(@DisplayedList)
    end

    # Deletes a given item ID, and refreshes everything.
    # It is assumed that we delete the currently displayed item.
    #
    # Parameters:
    # * *iItemID* (_Integer_): Item's ID to delete
    def deleteItem(iItemID)
      @DisplayedList.delete_at(iItemID)
      resetOptionsPanel
      refreshList
    end

    # Delete the last options panel
    def resetOptionsPanel
      if (@PluginOptionsPanel != nil)
        # First, update options if needed
        updateOptionsFromPanel
        # Then destroy everything
        @PluginOptionsPanel.destroy
        @PluginOptionsPanel = nil
        @DisplayedItemInfo = nil
      end
    end

    # Get options from the options panel to @DisplayedList
    def updateOptionsFromPanel
      if (@DisplayedItemInfo != nil)
        @DisplayedItemInfo[3] = @PluginOptionsPanel.getOptions
      end
    end

    # Set current components based on options
    #
    # Parameters:
    # * *iOptions* (<em>map<Symbol,Object></em>): Options
    def setOptions(iOptions)
      # Fill @DisplayedList
      @DisplayedList = []
      iOptions[:intPluginsOptions].each do |iPluginID, iPluginsList|
        iPluginsList.each do |iInstantiatedPluginInfo|
          iTag, iActive, iOptions, iInstance = iInstantiatedPluginInfo
          # We clone the options as we might modify them
          @DisplayedList << [ iPluginID, iTag, iActive, iOptions.clone, iInstance ]
        end
      end
      # Reflect new data in sub components
      refreshList
      resetOptionsPanel
    end

    # Fill the options from the components
    #
    # Parameters:
    # * *oOptions* (<em>map<Symbol,Object></em>): The options to fill
    def fillOptions(oOptions)
      # Get options from the panel first if needed
      updateOptionsFromPanel
      # Then write options based on @DisplayedList
      oOptions[:intPluginsOptions] = {}
      @DisplayedList.each do |iItemInfo|
        iPluginID, iTag, iActive, iOptions, iInstance = iItemInfo
        if (oOptions[:intPluginsOptions][iPluginID] == nil)
          oOptions[:intPluginsOptions][iPluginID] = []
        end
        oOptions[:intPluginsOptions][iPluginID] << [
          iTag,
          iActive,
          iOptions,
          iInstance
        ]
      end
    end

  end

end
