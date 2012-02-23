#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module define Actions that any Integration plugin (additional GUI) can use to:
  # * get easily toolbar buttons and menu items mapping PBS commands
  module GUIHelpers

    # Add a command in a menu.
    # This method does not return the created menu item, as it will be deleted/recreated each time its appearance will be updated (limitations certainly due to bugs).
    # To access to this menu later, always use the Wx::Menu object with the Command ID.
    #
    # Parameters::
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *ioMenu* (<em>Wx::Menu</em>): The menu in which we add the command
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    # * *iRegister* (_Boolean_): Do we register the menu item to the Controller for further updates ? [optional = true]
    # * *&iFetchParametersCode* (_CodeBlock_): Code that will use a command validator to fetch parameters, or nil if none needed
    def addMenuCommand(iEvtWindow, ioMenu, iCommandID, iParams = {}, iRegister = true, &iFetchParametersCode)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        log_bug "Unknown command of ID #{iCommandID}. Ignoring it from the menu."
      else
        lMenuItem = nil
        if (lCommand[:Checked] != nil)
          lMenuItem = Wx::MenuItem.new(ioMenu, iCommandID, '', '', Wx::ITEM_CHECK)
        else
          lMenuItem = Wx::MenuItem.new(ioMenu, iCommandID)
        end
        setMenuItemAppearanceWhileInsert(lMenuItem, iCommandID, ioMenu.menu_items.size, ioMenu, iEvtWindow, iFetchParametersCode)
        if (iRegister)
          lCommand[:RegisteredMenuItems] << [ lMenuItem, iEvtWindow, iFetchParametersCode, iParams ]
        end
      end
    end

    # Remove commands related to an event handler.
    #
    # Parameters::
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    def unregisterMenuEvt(iEvtWindow)
      @Commands.each do |iCommandID, ioCommand|
        ioCommand[:RegisteredMenuItems].delete_if do |iRegisteredMenuInfo|
          iMenuItem, iRegisteredEvtWindow, iCode, iParams = iRegisteredMenuInfo
          next (iRegisteredEvtWindow == iEvtWindow)
        end
      end
    end

    # Remove commands related to an event handler.
    #
    # Parameters::
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *iCommandID* (_Integer_): The corresponding command ID to unregister
    def unregisterMenuItem(iEvtWindow, iCommandID)
      @Commands.each do |iCommandID, ioCommand|
        ioCommand[:RegisteredMenuItems].delete_if do |iRegisteredMenuInfo|
          iMenuItem, iRegisteredEvtWindow, iCode, iParams = iRegisteredMenuInfo
          next ((iMenuItem.id == iCommandID) and
                (iRegisteredEvtWindow == iEvtWindow))
        end
      end
    end

    # Register a menu to receive menu items corresponding to the views configured in the options
    #
    # Parameters::
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *ioMenu* (<em>Wx::Menu</em>): The menu that will receive menu items for views
    # * *iRegister* (_Boolean_): Do we register the menu item to the Controller for further updates ? [optional = true]
    def registerViewsMenu(iEvtHandler, ioMenu, iRegister = true)
      # For each possible view, add a menu item
      lIdx = ID_VIEWS_BASE
      while (@Commands[lIdx] != nil)
        addMenuCommand(iEvtHandler, ioMenu, lIdx, {}, iRegister)
        lIdx += 1
      end
      if (iRegister)
        @ViewsMenu << [ iEvtHandler, ioMenu ]
      end
    end

    # Unregister a menu that received menu items corresponding to the views configured in the options
    #
    # Parameters::
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *ioMenu* (<em>Wx::Menu</em>): The menu that will receive menu items for views
    def unregisterViewsMenu(iEvtHandler, ioMenu)
      # Unregister each menu item from this menu
      lIdx = ID_VIEWS_BASE
      while (ioMenu.find_item(lIdx) != nil)
        # Unregister it
        unregisterMenuItem(iEvtHandler, lIdx)
        # Delete it
        ioMenu.delete(lIdx)
        # Check next one
        lIdx += 1
      end
      # Delete it from the views menu
      @ViewsMenu.delete_if do |iMenuInfo|
        next (iMenuInfo == [ iEvtHandler, ioMenu ])
      end
    end

    # Add a command in a toolbar
    #
    # Parameters::
    # * *iToolbar* (<em>Wx::Toolbar</em>): The toolbar in which we add the command
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    # * *iRegister* (_Boolean_): Do we register the menu item to the Controller for further updates ? [optional = true]
    # Return::
    # * <em>Wx::ToolbarTool</em>: The created toolbar button, or nil if none.
    def addToolbarCommand(iToolbar, iCommandID, iParams = {}, iRegister = true)
      rButton = nil
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        log_bug "Unknown command of ID #{iCommandID}. Ignoring it from the toolbar."
      else
        if (lCommand[:Checked] != nil)
          rButton = iToolbar.add_item(lCommand[:Bitmap], :id => iCommandID, :kind => Wx::ITEM_CHECK)
        else
          rButton = iToolbar.add_item(lCommand[:Bitmap], :id => iCommandID)
        end
        updateToolbarButtonAppearance(rButton, lCommand)
        if (iRegister)
          lCommand[:RegisteredToolbarButtons] << [ rButton, iParams ]
        end
      end

      return rButton
    end

    # Remove a whole toolbar
    #
    # Parameters::
    # * *iToolbar* (<em>Wx::Toolbar</em>): The toolbar in which we add the command
    def unregisterToolbar(iToolbar)
      @Commands.each do |iCommandID, ioCommand|
        ioCommand[:RegisteredToolbarButtons].delete_if do |iRegisteredToolbarButtonInfo|
          iButton, iParams = iRegisteredToolbarButtonInfo
          next (iButton.tool_bar == iToolbar)
        end
      end
    end

    # Update the GUI Enabled property of a menu item.
    # This property can put a veto to the enabling of a given command for this specific GUI (for example command Paste is enabled by the controller because there is something in the clipboard, but a particular GUI does not want it to be enabled because the user has not yet selected a place to Paste).
    #
    # Parameters::
    # * *iMenu* (<em>Wx::Menu</em>): Menu to which the menu item belongs.
    # * *iCommandID* (_Integer_): The command ID of the menu item
    # * *iGUIEnabled* (_Boolean_): Do we accept enabling the command ?
    def setMenuItemGUIEnabled(iMenu, iCommandID, iGUIEnabled)
      findRegisteredMenuItemParams(iMenu, iCommandID) do |ioParams|
        ioParams[:GUIEnabled] = iGUIEnabled
      end
    end

    # Update the GUI Title property of a menu item.
    # If set, this property will override the title given by the controller.
    #
    # Parameters::
    # * *iMenu* (<em>Wx::Menu</em>): Menu to which the menu item belongs.
    # * *iCommandID* (_Integer_): The command ID of the menu item
    # * *iGUITitle* (_String_): The title (can be nil to remove overiding the normal title)
    def setMenuItemGUITitle(iMenu, iCommandID, iGUITitle)
      findRegisteredMenuItemParams(iMenu, iCommandID) do |ioParams|
        ioParams[:GUITitle] = iGUITitle
      end
    end

    # Update the GUI Enabled property of a toolbar button
    # This property can put a veto to the enabling of a given command for this specific GUI (for example command Paste is enabled by the controller because there is something in the clipboard, but a particular GUI does not want it to be enabled because the user has not yet selected a place to Paste).
    #
    # Parameters::
    # * *iToolbarButton* (<em>Wx::ToolbarTool</em>): The toolbar button
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iGUIEnabled* (_Boolean_): Do we accept enabling the command ?
    def setToolbarButtonGUIEnabled(iToolbarButton, iCommandID, iGUIEnabled)
      findRegisteredToolbarButtonParams(iToolbarButton, iCommandID) do |ioParams|
        ioParams[:GUIEnabled] = iGUIEnabled
      end
    end

    # Update the GUI Title property of a toolbar button
    # If set, this property will override the title given by the controller.
    #
    # Parameters::
    # * *iToolbarButton* (<em>Wx::ToolbarTool</em>): The toolbar button
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iGUITitle* (_String_): The title
    def setToolbarButtonGUITitle(iToolbarButton, iCommandID, iGUITitle)
      findRegisteredToolbarButtonParams(iToolbarButton, iCommandID) do |ioParams|
        ioParams[:GUITitle] = iGUITitle
      end
    end

    # Block a given accelerator
    #
    # Parameters::
    # * *iAccelerator* (<em>[Integer,Integer]</em>): The accelerator to block
    def blockAccelerator(iAccelerator)
      # Find it among the commands
      @Commands.each do |iCommandID, ioCommand|
        if (ioCommand[:Accelerator] == iAccelerator)
          # Found it
          @BlockedAccelerators[iAccelerator] = iCommandID
          updateCommand(iCommandID) do |ioUpdateCommand|
            ioUpdateCommand[:Accelerator] = [ 0, K_NOKEY ]
            log_debug "Accelerator [#{iAccelerator.join(", ")}] blocked from command #{iCommandID}."
          end
          break
        end
      end
    end

    # Unblock a given accelerator previously blocked
    #
    # Parameters::
    # * *iAccelerator* (<em>[Integer,Integer]</em>): The accelerator to unblock
    def unblockAccelerator(iAccelerator)
      lCommandID = @BlockedAccelerators[iAccelerator]
      if (lCommandID != nil)
        updateCommand(lCommandID) do |ioUpdateCommand|
          ioUpdateCommand[:Accelerator] = iAccelerator
          log_debug "Accelerator [#{iAccelerator.join(", ")}] unblocked from command #{lCommandID}."
        end
      end
    end

  end

end
