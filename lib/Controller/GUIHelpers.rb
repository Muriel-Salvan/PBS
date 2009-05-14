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
              puts "!!! Unknown command of ID #{iCommandID}. Ignoring it from the accelerator table."
            else
              @AcceleratorTable << Wx::AcceleratorEntry.new(lCommand[:accelerator][0], lCommand[:accelerator][1], iCommandID)
            end
          end
        end
      end
      oFrame.accelerator_table = Wx::AcceleratorTable.new(@AcceleratorTable)
    end

    # Add a command in a menu
    #
    # Parameters:
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *ioMenu* (<em>Wx::Menu</em>): The menu in which we add the command
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *&iFetchParametersCode* (_CodeBlock_): Code that will use a command validator to fetch parameters, or nil if none needed
    def addMenuCommand(iEvtWindow, ioMenu, iCommandID, &iFetchParametersCode)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        puts "!!! Unknown command of ID #{iCommandID}. Ignoring it from the menu."
      else
        lMenuItem = Wx::MenuItem.new(ioMenu, iCommandID)
        lCommand[:registeredMenuItems] << [ lMenuItem, iEvtWindow, iFetchParametersCode ]
        setMenuItemAppearanceWhileInsert(lMenuItem, iCommandID, ioMenu.menu_items.size, ioMenu, iEvtWindow, iFetchParametersCode)
      end
    end

    # Add a command in a toolbar
    #
    # Parameters:
    # * *iToolbar* (<em>Wx::Toolbar</em>): The toolbar in which we add the command
    # * *iCommandID* (_Integer_): ID of the command to add
    def addToolbarCommand(iToolbar, iCommandID)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        puts "!!! Unknown command of ID #{iCommandID}. Ignoring it from the toolbar."
      else
        lButton = iToolbar.add_item(lCommand[:bitmap], :id => iCommandID)
        lCommand[:registeredToolbarButtons] << lButton
        updateToolbarButtonAppearance(lButton, lCommand)
      end
    end

  end

end
