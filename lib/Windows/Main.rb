#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/PBSTreeCtrl.rb'

module PBS

  # TODO: Place this in a separate common file with the method using it.
  SPECIALKEYS_STR = {
    Wx::K_BACK => 'Backspace',
    Wx::K_TAB => 'Tab',
    Wx::K_RETURN => 'Enter',
    Wx::K_ESCAPE => 'Escape',
    Wx::K_SPACE => 'Space',
    Wx::K_DELETE => 'Del',
    Wx::K_START => 'Start',
    Wx::K_LBUTTON => 'Mouse Left',
    Wx::K_RBUTTON => 'Mouse Right',
    Wx::K_CANCEL => 'Cancel',
    Wx::K_MBUTTON => 'Mouse Middle',
    Wx::K_CLEAR => 'Clear',
    Wx::K_SHIFT => 'Shift',
    Wx::K_ALT => 'Alt',
    Wx::K_CONTROL => 'Control',
    Wx::K_MENU => 'Menu',
    Wx::K_PAUSE => 'Pause',
    Wx::K_CAPITAL => 'Capital',
    Wx::K_END => 'End',
    Wx::K_HOME => 'Home',
    Wx::K_LEFT => 'Left',
    Wx::K_UP => 'Up',
    Wx::K_RIGHT => 'Right',
    Wx::K_DOWN => 'Down',
    Wx::K_SELECT => 'Select',
    Wx::K_PRINT => 'Print',
    Wx::K_EXECUTE => 'Execute',
    Wx::K_SNAPSHOT => 'Snapshot',
    Wx::K_INSERT => 'Ins',
    Wx::K_HELP => 'Help',
    Wx::K_NUMPAD0 => 'Num 0',
    Wx::K_NUMPAD1 => 'Num 1',
    Wx::K_NUMPAD2 => 'Num 2',
    Wx::K_NUMPAD3 => 'Num 3',
    Wx::K_NUMPAD4 => 'Num 4',
    Wx::K_NUMPAD5 => 'Num 5',
    Wx::K_NUMPAD6 => 'Num 6',
    Wx::K_NUMPAD7 => 'Num 7',
    Wx::K_NUMPAD8 => 'Num 8',
    Wx::K_NUMPAD9 => 'Num 9',
    Wx::K_MULTIPLY => '*',
    Wx::K_ADD => '+',
    Wx::K_SEPARATOR => 'Separator',
    Wx::K_SUBTRACT => '-',
    Wx::K_DECIMAL => '.',
    Wx::K_DIVIDE => '/',
    Wx::K_F1 => 'F1',
    Wx::K_F2 => 'F2',
    Wx::K_F3 => 'F3',
    Wx::K_F4 => 'F4',
    Wx::K_F5 => 'F5',
    Wx::K_F6 => 'F6',
    Wx::K_F7 => 'F7',
    Wx::K_F8 => 'F8',
    Wx::K_F9 => 'F9',
    Wx::K_F10 => 'F10',
    Wx::K_F11 => 'F11',
    Wx::K_F12 => 'F12',
    Wx::K_F13 => 'F13',
    Wx::K_F14 => 'F14',
    Wx::K_F15 => 'F15',
    Wx::K_F16 => 'F16',
    Wx::K_F17 => 'F17',
    Wx::K_F18 => 'F18',
    Wx::K_F19 => 'F19',
    Wx::K_F20 => 'F20',
    Wx::K_F21 => 'F21',
    Wx::K_F22 => 'F22',
    Wx::K_F23 => 'F23',
    Wx::K_F24 => 'F24',
    Wx::K_NUMLOCK => 'Numlock',
    Wx::K_SCROLL => 'Scroll',
    Wx::K_PAGEUP => 'PageUp',
    Wx::K_PAGEDOWN => 'PageDown',
    Wx::K_NUMPAD_SPACE => 'Num Space',
    Wx::K_NUMPAD_TAB => 'Num Tab',
    Wx::K_NUMPAD_ENTER => 'Num Enter',
    Wx::K_NUMPAD_F1 => 'Num F1',
    Wx::K_NUMPAD_F2 => 'Num F2',
    Wx::K_NUMPAD_F3 => 'Num F3',
    Wx::K_NUMPAD_F4 => 'Num F4',
    Wx::K_NUMPAD_HOME => 'Num Home',
    Wx::K_NUMPAD_LEFT => 'Num Left',
    Wx::K_NUMPAD_UP => 'Num Up',
    Wx::K_NUMPAD_RIGHT => 'Num Right',
    Wx::K_NUMPAD_DOWN => 'Num Down',
    Wx::K_NUMPAD_PAGEUP => 'Num PageUp',
    Wx::K_NUMPAD_PAGEDOWN => 'Num PageDown',
    Wx::K_NUMPAD_END => 'Num End',
    Wx::K_NUMPAD_BEGIN => 'Num Begin',
    Wx::K_NUMPAD_INSERT => 'Num Ins',
    Wx::K_NUMPAD_DELETE => 'Num Del',
    Wx::K_NUMPAD_EQUAL => 'Num =',
    Wx::K_NUMPAD_MULTIPLY => 'Num *',
    Wx::K_NUMPAD_ADD => 'Num +',
    Wx::K_NUMPAD_SEPARATOR => 'Num Separator',
    Wx::K_NUMPAD_SUBTRACT => 'Num -',
    Wx::K_NUMPAD_DECIMAL => 'Num .',
    Wx::K_NUMPAD_DIVIDE => 'Num /',
    Wx::K_WINDOWS_LEFT => 'Win Left',
    Wx::K_WINDOWS_RIGHT => 'Win Right',
    Wx::K_WINDOWS_MENU => 'Win Menu',
    Wx::K_COMMAND => 'Command',
    Wx::K_SPECIAL1 => 'Special 1',
    Wx::K_SPECIAL2 => 'Special 2',
    Wx::K_SPECIAL3 => 'Special 3',
    Wx::K_SPECIAL4 => 'Special 4',
    Wx::K_SPECIAL5 => 'Special 5',
    Wx::K_SPECIAL6 => 'Special 6',
    Wx::K_SPECIAL7 => 'Special 7',
    Wx::K_SPECIAL8 => 'Special 8',
    Wx::K_SPECIAL9 => 'Special 9',
    Wx::K_SPECIAL10 => 'Special 10',
    Wx::K_SPECIAL11 => 'Special 11',
    Wx::K_SPECIAL12 => 'Special 12',
    Wx::K_SPECIAL13 => 'Special 13',
    Wx::K_SPECIAL14 => 'Special 14',
    Wx::K_SPECIAL15 => 'Special 15',
    Wx::K_SPECIAL16 => 'Special 16',
    Wx::K_SPECIAL17 => 'Special 17',
    Wx::K_SPECIAL18 => 'Special 18',
    Wx::K_SPECIAL19 => 'Special 19',
    Wx::K_SPECIAL20 => 'Special 20'
  }

  # Main application frame
  class MainFrame < Wx::Frame

    include Tools

    # Set the title of the application, depending on the context
    def setAppTitle
      lAppTitle ="Portable Bookmarks and Shortcuts v#{$PBS_VERSION}"
      if (@Controller.CurrentOpenedFileName != nil)
        # Display the currently opened file name, without the path nor the extension as we are short on space
        lFileName = File.basename(@Controller.CurrentOpenedFileName)[0..-6]
        if (@Controller.CurrentOpenedFileModified)
          self.title = "#{lFileName} * - #{lAppTitle}"
        else
          self.title = "#{lFileName} - #{lAppTitle}"
        end
      else
        self.title = lAppTitle
      end
    end

    # Notify the GUI that data on the currently opened file has been modified
    def onCurrentOpenedFileUpdate
      setAppTitle
    end

    # Clipboard's selection has changed
    def onClipboardContentChanged
      if (@TCMainTree.isRootTagOnlySelected?)
        refreshPaste(nil)
      else
        refreshPaste(@TCMainTree.getCurrentSelection)
      end
    end

    # Options have changed
    #
    # Parameters:
    # * *iOldOptions* (<em>map<Symbol,Object></em>): The old options
    def onOptionsChanged(iOldOptions)
      if (@TCMainTree.isRootTagOnlySelected?)
        refreshPaste(nil)
      else
        refreshPaste(@TCMainTree.getCurrentSelection)
      end
    end

    # Notify that we are exiting
    def onExit
      $PBS_Exiting = true
      self.destroy
    end

    # Method called when the selection of the main tree has changed
    def onMainTreeSelectionUpdated
      if (@TCMainTree.selectionChanged?)
        lSelection = @TCMainTree.getCurrentSelection
        lName = lSelection.getDescription
        # Group Cut/Copy/Delete:
        # Enabled only if the selection is not empty
        [ [ Wx::ID_CUT, 'Cut' ],
          [ Wx::ID_COPY, 'Copy' ],
          [ Wx::ID_DELETE, 'Delete' ] ].each do |iCommandInfo|
          iCommandID, iCommandName = iCommandInfo
          @Controller.setMenuItemGUIEnabled(@EditMenu, iCommandID, (!lSelection.empty?))
          if (lName != nil)
            @Controller.setMenuItemGUITitle(@EditMenu, iCommandID, "#{iCommandName} #{lName}")
          else
            @Controller.setMenuItemGUITitle(@EditMenu, iCommandID, nil)
          end
          lButton = @ToolBar.find_by_id(iCommandID)
          if (lButton != nil)
            @Controller.setToolbarButtonGUIEnabled(lButton, iCommandID, (!lSelection.empty?))
            if (lName != nil)
              @Controller.setToolbarButtonGUITitle(lButton, iCommandID, "#{iCommandName} #{lName}")
            else
              @Controller.setToolbarButtonGUITitle(lButton, iCommandID, nil)
            end
          end
        end
        # Group Edit:
        # Enabled only if the selection contains a single Tag or a single Shortcut
        lEditEnabled = ((lSelection.singleTag?) or
                        (lSelection.singleShortcut?))
        @Controller.setMenuItemGUIEnabled(@EditMenu, Wx::ID_EDIT, lEditEnabled)
        if (lName != nil)
          @Controller.setMenuItemGUITitle(@EditMenu, Wx::ID_EDIT, "Edit #{lName}")
        else
          @Controller.setMenuItemGUITitle(@EditMenu, Wx::ID_EDIT, nil)
        end
        lButton = @ToolBar.find_by_id(Wx::ID_EDIT)
        if (lButton != nil)
          @Controller.setToolbarButtonGUIEnabled(lButton, Wx::ID_EDIT, lEditEnabled)
          if (lName != nil)
            @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, "Edit #{lName}")
          else
            @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, nil)
          end
        end
        # Group New Tag/New Shortcut:
        # Enabled only if the selection contains a single Tag or the Root Tag
        lTagOpEnabled = ((@TCMainTree.isRootTagOnlySelected?) or
                         (lSelection.singleTag?))
        @Controller.setMenuItemGUIEnabled(@EditMenu, ID_NEW_TAG, lTagOpEnabled)
        lButton = @ToolBar.find_by_id(ID_NEW_TAG)
        if (lButton != nil)
          @Controller.setToolbarButtonGUIEnabled(lButton, ID_NEW_TAG, lTagOpEnabled)
        end
        @Controller.TypesPlugins.each do |iTypeID, iTypeInfo|
          lIdxID = ID_NEW_SHORTCUT_BASE + iTypeInfo[:index]
          @Controller.setMenuItemGUIEnabled(@NewShortcutMenu, lIdxID, lTagOpEnabled)
          lButton = @ToolBar.find_by_id(lIdxID)
          if (lButton != nil)
            @Controller.setToolbarButtonGUIEnabled(lButton, lIdxID, lTagOpEnabled)
          end
        end
        # Group Paste:
        if (@TCMainTree.isRootTagOnlySelected?)
          refreshPaste(nil)
        else
          refreshPaste(lSelection)
        end
        # Shortcut Command Plugins
        @Controller.ShortcutCommandsPlugins.each do |iPluginID, iPluginInfo|
          lCommandID = ID_SHORTCUT_COMMAND_BASE + iPluginInfo[:index]
          if ((!lSelection.SelectedPrimaryShortcuts.empty?) or
              (!lSelection.SelectedSecondaryShortcuts.empty?))
            # Is the plugin available ?
            lAvailable = false
            if (iPluginInfo[:shortcutTypes] == nil)
              # This command is available
              lAvailable = true
            else
              (lSelection.SelectedPrimaryShortcuts + lSelection.SelectedSecondaryShortcuts).each do |iSelectedShortcutInfo|
                iSelectedShortcut, iParentTag = iSelectedShortcutInfo
                if (iPluginInfo[:shortcutTypes].include?(iSelectedShortcut.Type.pluginName))
                  # there is at least 1 Shortcut that is eligible.
                  lAvailable = true
                  break
                end
              end
            end
            if (lAvailable)
              @Controller.setMenuItemGUIEnabled(@ShortcutCommandsMenu, lCommandID, true)
              @Controller.setMenuItemGUITitle(@ShortcutCommandsMenu, lCommandID, nil)
              lButton = @ToolBar.find_by_id(ID_NEW_TAG)
              if (lButton != nil)
                @Controller.setToolbarButtonGUIEnabled(lButton, lCommandID, true)
                @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, nil)
              end
            else
              @Controller.setMenuItemGUIEnabled(@ShortcutCommandsMenu, lCommandID, false)
              @Controller.setMenuItemGUITitle(@ShortcutCommandsMenu, lCommandID, "#{iPluginInfo[:title]}: No applicable Shortcut")
              lButton = @ToolBar.find_by_id(ID_NEW_TAG)
              if (lButton != nil)
                @Controller.setToolbarButtonGUIEnabled(lButton, lCommandID, false)
                @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, "#{iPluginInfo[:title]}: No applicable Shortcut")
              end
            end
          else
            # No Shortcut selected
            @Controller.setMenuItemGUIEnabled(@ShortcutCommandsMenu, lCommandID, false)
            @Controller.setMenuItemGUITitle(@ShortcutCommandsMenu, lCommandID, "#{iPluginInfo[:title]}: No Shortcut selected")
            lButton = @ToolBar.find_by_id(ID_NEW_TAG)
            if (lButton != nil)
              @Controller.setToolbarButtonGUIEnabled(lButton, lCommandID, false)
              @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, "#{iPluginInfo[:title]}: No Shortcut selected")
            end
          end
        end
      end
    end

    # Refresh the Paste GUI items (enabling + title), based on the clipboard content and the current selection
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection (nil for the Root Tag)
    def refreshPaste(iSelection)
      lPasteEnabled = false
      lErrors = []
      if (@Controller.Clipboard_CopyMode != nil)
        lLocalSelection = nil
        if (@Controller.Clipboard_CopyID == @Controller.CopiedID)
          lLocalSelection = @Controller.CopiedSelection
        end
        lPasteEnabled, lErrors = isPasteAuthorized?(
          @Controller,
          iSelection,
          @Controller.Clipboard_CopyMode,
          lLocalSelection,
          @Controller.Clipboard_SerializedSelection
        )
      end
      @Controller.setMenuItemGUIEnabled(@EditMenu, Wx::ID_PASTE, lPasteEnabled)
      if (lErrors.empty?)
        @Controller.setMenuItemGUITitle(@EditMenu, Wx::ID_PASTE, nil)
      else
        @Controller.setMenuItemGUITitle(@EditMenu, Wx::ID_PASTE, "Unable to paste: #{lErrors.join(' & ')}")
      end
      lButton = @ToolBar.find_by_id(Wx::ID_PASTE)
      if (lButton != nil)
        @Controller.setToolbarButtonGUIEnabled(lButton, Wx::ID_PASTE, lPasteEnabled)
        if (lErrors.empty?)
          @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_PASTE, nil)
        else
          @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_PASTE, "Unable to paste: #{lErrors.join(' & ')}")
        end
      end
    end

    # Add a command to a menu belonging to this main frame
    #
    # Parameters:
    # * *iMenu* (<em>Wx::Menu</em>): The menu the command will belong to
    # * *iCommandID* (_Integer_): The command ID
    # * *&iFetchParametersCode* (_CodeBlock_): The code that will fetch for parameters for this command (can be nil)
    def addMenuCommand(iMenu, iCommandID, &iFetchParametersCode)
      @Controller.addMenuCommand(self, iMenu, iCommandID, &iFetchParametersCode)
    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iController* (_Controller_): The model controller
    def initialize(iParent, iController)
      super(iParent)
      @Controller = iController

      # The close event
      evt_close do |iEvent|
        # Reset this variable
        $PBS_Exiting = nil
        @Controller.executeCommand(Wx::ID_EXIT, {
          :parentWindow => self
        })
        if ($PBS_Exiting == nil)
          # There was a problem. Log it and close.
          logBug "An error occurred while closing. Forcing close."
          self.destroy
        end
      end

      # Create the main treeview
      @TCMainTree = PBSTreeCtrl.new(@Controller, self)
    end

    # Initialize everything, based on the controller
    def init
      # We register the tree controller itself, as it contains plenty of onXxxx methods.
      @Controller.registerGUI(@TCMainTree)

      # Create the menus
      # File menu
      lFileMenu = Wx::Menu.new
      addMenuCommand(lFileMenu, Wx::ID_OPEN) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end
      addMenuCommand(lFileMenu, ID_OPEN_MERGE) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end
      addMenuCommand(lFileMenu, Wx::ID_SAVE)
      addMenuCommand(lFileMenu, Wx::ID_SAVEAS) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end
      lFileMenu.append_separator
      lImportMenu = Wx::Menu.new
      @Controller.ImportPlugins.each do |iImportID, iImportInfo|
        addMenuCommand(lImportMenu, ID_IMPORT_BASE + iImportInfo[:index]) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => self
          )
        end
      end
      lFileMenu.append_sub_menu(lImportMenu, 'Import')
      lImportMergeMenu = Wx::Menu.new
      @Controller.ImportPlugins.each do |iImportID, iImportInfo|
        addMenuCommand(lImportMergeMenu, ID_IMPORT_MERGE_BASE + iImportInfo[:index]) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => self
          )
        end
      end
      lFileMenu.append_sub_menu(lImportMergeMenu, 'Import and Merge')
      lExportMenu = Wx::Menu.new
      @Controller.ExportPlugins.each do |iExportID, iExportInfo|
        addMenuCommand(lExportMenu, ID_EXPORT_BASE + iExportInfo[:index]) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => self
          )
        end
      end
      lFileMenu.append_sub_menu(lExportMenu, 'Export')
      lFileMenu.append_separator
      addMenuCommand(lFileMenu, Wx::ID_EXIT) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end
      # Edit menu
      @EditMenu = Wx::Menu.new
      addMenuCommand(@EditMenu, Wx::ID_UNDO)
      addMenuCommand(@EditMenu, Wx::ID_REDO)
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, Wx::ID_CUT) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :selection => @TCMainTree.getCurrentSelection
        )
      end
      addMenuCommand(@EditMenu, Wx::ID_COPY) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :selection => @TCMainTree.getCurrentSelection
        )
      end
      addMenuCommand(@EditMenu, Wx::ID_PASTE) do |iEvent, oValidator|
        # Here, we are sure the selection is on 1 Tag only, or the root Tag
        if (@TCMainTree.isRootTagOnlySelected?)
          oValidator.authorizeCmd(
            :tag => @Controller.RootTag
          )
        else
          oValidator.authorizeCmd(
            :tag => @TCMainTree.getCurrentSelection.SelectedPrimaryTags[0]
          )
        end
      end
      addMenuCommand(@EditMenu, Wx::ID_DELETE) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :selection => @TCMainTree.getCurrentSelection,
          :parentWindow => self,
          :deleteTaggedShortcuts => nil,
          :deleteOrphanShortcuts => nil
        )
      end
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, Wx::ID_FIND)
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, Wx::ID_EDIT) do |iEvent, oValidator|
        # We are sure a single Tag or a single Shortcut are selected
        lSelection = @TCMainTree.getCurrentSelection
        if (lSelection.singleTag?)
          # A Tag is selected
          oValidator.authorizeCmd(
            :parentWindow => self,
            :objectID => ID_TAG,
            :object => lSelection.SelectedPrimaryTags[0]
          )
        elsif (lSelection.singleShortcut?)
          # A Shortcut is selected
          oValidator.authorizeCmd(
            :parentWindow => self,
            :objectID => ID_SHORTCUT,
            :object => lSelection.SelectedPrimaryShortcuts[0][0]
          )
        else
          oValidator.setError("Normally a single Shortcut or Tag was selected: #{lSelection.getDescription}. However we are unable to retrieve it. Bug ?")
        end
      end
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, ID_NEW_TAG) do |iEvent, oValidator|
        # Here, we are sure the selection is on 1 Tag only (maybe the root)
        if (@TCMainTree.isRootTagOnlySelected?)
          oValidator.authorizeCmd(
            :tag => @Controller.RootTag,
            :parentWindow => self
          )
        else
          oValidator.authorizeCmd(
            :tag => @TCMainTree.getCurrentSelection.SelectedPrimaryTags[0],
            :parentWindow => self
          )
        end
      end
      @NewShortcutMenu = Wx::Menu.new
      @Controller.TypesPlugins.each do |iTypeID, iTypeInfo|
        addMenuCommand(@NewShortcutMenu, ID_NEW_SHORTCUT_BASE + iTypeInfo[:index]) do |iEvent, oValidator|
          # Here, we are sure the selection is on 1 Tag only (maybe the root)
          if (@TCMainTree.isRootTagOnlySelected?)
            oValidator.authorizeCmd(
              :tag => nil,
              :parentWindow => self
            )
          else
            oValidator.authorizeCmd(
              :tag => @TCMainTree.getCurrentSelection.SelectedPrimaryTags[0],
              :parentWindow => self
            )
          end
        end
      end
      @EditMenu.append_sub_menu(@NewShortcutMenu, 'New Shortcut')
      @EditMenu.append_separator
      @ShortcutCommandsMenu = Wx::Menu.new
      @Controller.ShortcutCommandsPlugins.each do |iPluginID, iPluginInfo|
        addMenuCommand(@ShortcutCommandsMenu, ID_SHORTCUT_COMMAND_BASE + iPluginInfo[:index]) do |iEvent, oValidator|
          # Here, we are sure the selection accepts this command
          lSelection = @TCMainTree.getCurrentSelection
          # Set of selected Shortcuts
          # map< Shortcut, nil >
          lSelectedShortcuts = {}
          (lSelection.SelectedPrimaryShortcuts + lSelection.SelectedSecondaryShortcuts).each do |iSelectedShortcutInfo|
            iSelectedShortcut, iParentTag = iSelectedShortcutInfo
            lSelectedShortcuts[iSelectedShortcut] = nil
          end
          # And now call the command for each Shortcut that is filtered by the :shortcutTypes attribute of the plugin
          lShortcutsList = []
          lSelectedShortcuts.each do |iShortcut, iNil|
            if ((iPluginInfo[:shortcutTypes] == nil) or
                (iPluginInfo[:shortcutTypes].include?(iShortcut.Type.pluginName)))
              lShortcutsList << iShortcut
            end
          end
          oValidator.authorizeCmd(
            :shortcutsList => lShortcutsList
          )
        end
      end
      @EditMenu.append_sub_menu(@ShortcutCommandsMenu, 'Shortcuts operations')

      # Tools menu
      lToolsMenu = Wx::Menu.new
      addMenuCommand(lToolsMenu, Wx::ID_SETUP) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end
      addMenuCommand(lToolsMenu, ID_STATS)
      if ($PBS_DevDebug)
        addMenuCommand(lToolsMenu, ID_DEVDEBUG)
      end
      # Help menu
      lHelpMenu = Wx::Menu.new
      addMenuCommand(lHelpMenu, Wx::ID_HELP)
      addMenuCommand(lHelpMenu, ID_TIPS) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end
      addMenuCommand(lHelpMenu, Wx::ID_ABOUT) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :parentWindow => self
        )
      end

      # Create the menu bar
      lMenu = Wx::MenuBar.new
      lMenu.append(lFileMenu, 'File')
      lMenu.append(@EditMenu, 'Edit')
      lMenu.append(lToolsMenu, 'Tools')
      lMenu.append(lHelpMenu, 'Help')
      self.menu_bar = lMenu

      # Instantiate a default toolbar
      lDefaultToolBar = [
        Wx::ID_OPEN,
        Wx::ID_SAVEAS,
        Wx::ID_SEPARATOR,
        Wx::ID_EDIT,
        Wx::ID_UNDO,
        Wx::ID_REDO,
        Wx::ID_COPY,
        Wx::ID_PASTE
      ]
      if ($PBS_DevDebug)
        lDefaultToolBar << ID_DEVDEBUG
      end

      # Create the toolbar
      @ToolBar = Wx::ToolBar.new(self,
        :style => Wx::TB_FLAT|Wx::TB_HORIZONTAL
      )
      lDefaultToolBar.each do |iCommandID|
        if (iCommandID == Wx::ID_SEPARATOR)
          @ToolBar.add_separator
        else
          @Controller.addToolbarCommand(@ToolBar, iCommandID)
        end
      end
      @ToolBar.realize
      self.tool_bar = @ToolBar

      # Create the status bar
      lStatusBar = Wx::StatusBar.new(self)
      self.status_bar = lStatusBar

      # Set the Accelerator table for this frame
      @Controller.setAcceleratorTableForFrame(self)

      # Set the main tree context menu
      @TCMainTree.setContextMenu(@EditMenu)

      # Don't forget the main icon
      self.icon = Wx::Icon.from_bitmap(Tools::loadBitmap('Icon32.png'))

      # Set the application title, as it depends on context
      setAppTitle

      # Enables Copy/Cut/Delete/Edit/Paste depending on selected items in the tree
      evt_tree_sel_changed(@TCMainTree) do |iEvent|
        onMainTreeSelectionUpdated
      end
      @TCMainTree.evt_left_up do |iEvent|
        onMainTreeSelectionUpdated
      end

      # Resize it as it will always be resized by users having more than 10 shortcuts
      self.size = [300, 400]
    end

  end

end
