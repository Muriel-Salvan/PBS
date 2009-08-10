#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module define Actions that any Integration plugin (additional GUI) can use to:
  # * get easily toolbar buttons and menu items mapping PBS commands
  module GUIHelpers

    # Set the accelerator table for a given frame
    #
    # Parameters:
    # * *oFrame* (<em>Wx::Frame</em>): The frame for which we set the accelerator table
    def setAcceleratorTableForFrame(oFrame)
      if (!defined?(@AcceleratorTable))
        # Cache it for performance
        @AcceleratorTable = []
        @Commands.each do |iCommandID, iCommand|
          if (iCommand[:accelerator] != nil)
            lCommand = @Commands[iCommandID]
            if (lCommand == nil)
              logBug "Unknown command of ID #{iCommandID}. Ignoring it from the accelerator table."
            else
              @AcceleratorTable << Wx::AcceleratorEntry.new(lCommand[:accelerator][0], lCommand[:accelerator][1], iCommandID)
            end
          end
        end
      end
      oFrame.accelerator_table = Wx::AcceleratorTable.new(@AcceleratorTable)
    end

    # Add a command in a menu.
    # this method does not return the created menu item, as it will be deleted/recreated each time its appearance will be updated (limitations certainly due to bugs).
    # To access to this menu later, always use the Wx::Menu object with the Command ID.
    #
    # Parameters:
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *ioMenu* (<em>Wx::Menu</em>): The menu in which we add the command
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    # * *&iFetchParametersCode* (_CodeBlock_): Code that will use a command validator to fetch parameters, or nil if none needed
    def addMenuCommand(iEvtWindow, ioMenu, iCommandID, iParams = {}, &iFetchParametersCode)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        logBug "Unknown command of ID #{iCommandID}. Ignoring it from the menu."
      else
        lMenuItem = Wx::MenuItem.new(ioMenu, iCommandID)
        lCommand[:registeredMenuItems] << [ lMenuItem, iEvtWindow, iFetchParametersCode, iParams ]
        setMenuItemAppearanceWhileInsert(lMenuItem, iCommandID, ioMenu.menu_items.size, ioMenu, iEvtWindow, iFetchParametersCode)
      end
    end

    # Add a command in a toolbar
    #
    # Parameters:
    # * *iToolbar* (<em>Wx::Toolbar</em>): The toolbar in which we add the command
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    # Return:
    # * <em>Wx::ToolbarTool</em>: The created toolbar button, or nil if none.
    def addToolbarCommand(iToolbar, iCommandID, iParams = {})
      rButton = nil

      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        logBug "Unknown command of ID #{iCommandID}. Ignoring it from the toolbar."
      else
        rButton = iToolbar.add_item(lCommand[:bitmap], :id => iCommandID)
        lCommand[:registeredToolbarButtons] << [ rButton, iParams ]
        updateToolbarButtonAppearance(rButton, lCommand)
      end

      return rButton
    end

    # Update the GUI Enabled property of a menu item.
    # This property can put a veto to the enabling of a given command for this specific GUI (for example command Paste is enabled by the controller because there is something in the clipboard, but a particular GUI does not want it to be enabled because the user has not yet selected a place to Paste).
    #
    # Parameters:
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
    # Parameters:
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
    # Parameters:
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
    # Parameters:
    # * *iToolbarButton* (<em>Wx::ToolbarTool</em>): The toolbar button
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *iGUITitle* (_String_): The title
    def setToolbarButtonGUITitle(iToolbarButton, iCommandID, iGUITitle)
      findRegisteredToolbarButtonParams(iToolbarButton, iCommandID) do |ioParams|
        ioParams[:GUITitle] = iGUITitle
      end
    end

  end

end
