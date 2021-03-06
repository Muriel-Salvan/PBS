#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Main application frame
  class MainFrame < Wx::Frame

    # Set the title of the application, depending on the context
    def setAppTitle
      lAppTitle ="Portable Bookmarks and Shortcuts v#{$PBS_ReleaseInfo[:Version]}"
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

    # Options specifics to this plugin have changed
    #
    # Parameters::
    # * *iNewOptions* (_Object_): The new options
    # * *iNewTag* (_Tag_): The new Tag to integrate
    # * *iOldOptions* (_Object_): The old options (can be nil during startup)
    # * *iOldTag* (_Tag_): The old Tag to integrate (can be nil during startup)
    def onPluginOptionsChanged(iNewOptions, iNewTag, iOldOptions, iOldTag)
      @TCMainTree.setRootTag(iNewTag)
      # Set our icon to the Tag's one
      if (iNewTag == @Controller.RootTag)
        self.icon = Wx::Icon.from_bitmap(getGraphic('Icon32.png'))
      else
        self.icon = Wx::Icon.from_bitmap(@Controller.getTagIcon(iNewTag))
      end
    end

    # Options have changed
    #
    # Parameters::
    # * *iOldOptions* (<em>map<Symbol,Object></em>): The old options
    def onOptionsChanged(iOldOptions)
      if (@TCMainTree.isRootTagOnlySelected?)
        refreshPaste(nil)
      else
        refreshPaste(@TCMainTree.getCurrentSelection)
      end
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
        @Controller.getTypesPlugins.each do |iTypeID, iTypeInfo|
          lIdxID = ID_NEW_SHORTCUT_BASE + iTypeInfo[:PluginIndex]
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
        @Controller.getShortcutCommandsPlugins.each do |iPluginID, iPluginInfo|
          lCommandID = ID_SHORTCUT_COMMAND_BASE + iPluginInfo[:PluginIndex]
          if ((!lSelection.SelectedPrimaryShortcuts.empty?) or
              (!lSelection.SelectedSecondaryShortcuts.empty?))
            # Is the plugin available ?
            lAvailable = false
            if (iPluginInfo[:ShortcutTypes] == nil)
              # This command is available
              lAvailable = true
            else
              (lSelection.SelectedPrimaryShortcuts + lSelection.SelectedSecondaryShortcuts).each do |iSelectedShortcutInfo|
                iSelectedShortcut, iParentTag = iSelectedShortcutInfo
                if (iPluginInfo[:ShortcutTypes].include?(iSelectedShortcut.Type.pluginDescription[:PluginName]))
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
              @Controller.setMenuItemGUITitle(@ShortcutCommandsMenu, lCommandID, "#{iPluginInfo[:Title]}: No applicable Shortcut")
              lButton = @ToolBar.find_by_id(ID_NEW_TAG)
              if (lButton != nil)
                @Controller.setToolbarButtonGUIEnabled(lButton, lCommandID, false)
                @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, "#{iPluginInfo[:Title]}: No applicable Shortcut")
              end
            end
          else
            # No Shortcut selected
            @Controller.setMenuItemGUIEnabled(@ShortcutCommandsMenu, lCommandID, false)
            @Controller.setMenuItemGUITitle(@ShortcutCommandsMenu, lCommandID, "#{iPluginInfo[:Title]}: No Shortcut selected")
            lButton = @ToolBar.find_by_id(ID_NEW_TAG)
            if (lButton != nil)
              @Controller.setToolbarButtonGUIEnabled(lButton, lCommandID, false)
              @Controller.setToolbarButtonGUITitle(lButton, Wx::ID_EDIT, "#{iPluginInfo[:Title]}: No Shortcut selected")
            end
          end
        end
      end
    end

    # Refresh the Paste GUI items (enabling + title), based on the clipboard content and the current selection
    #
    # Parameters::
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
    # Parameters::
    # * *iMenu* (<em>Wx::Menu</em>): The menu the command will belong to
    # * *iCommandID* (_Integer_): The command ID
    # * *&iFetchParametersCode* (_CodeBlock_): The code that will fetch for parameters for this command (can be nil)
    def addMenuCommand(iMenu, iCommandID, &iFetchParametersCode)
      @Controller.addMenuCommand(self, iMenu, iCommandID, &iFetchParametersCode)
    end

    # Constructor
    #
    # Parameters::
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iController* (_Controller_): The model controller
    def initialize(iParent, iController)
      super(iParent)
      @Controller = iController

      # The close event
      evt_close do |iEvent|
        @Controller.executeCommand(Wx::ID_CLOSE, :instancesToClose => [ self ] )
      end

      # Create the main treeview
      require 'pbs/Windows/PBSTreeCtrl'
      @TCMainTree = PBSTreeCtrl.new(@Controller, self)

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
      @Controller.getImportPlugins.each do |iImportID, iImportInfo|
        addMenuCommand(lImportMenu, ID_IMPORT_BASE + iImportInfo[:PluginIndex]) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => self
          )
        end
      end
      lFileMenu.append_sub_menu(lImportMenu, 'Import')
      lImportMergeMenu = Wx::Menu.new
      @Controller.getImportPlugins.each do |iImportID, iImportInfo|
        addMenuCommand(lImportMergeMenu, ID_IMPORT_MERGE_BASE + iImportInfo[:PluginIndex]) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => self
          )
        end
      end
      lFileMenu.append_sub_menu(lImportMergeMenu, 'Import and Merge')
      lExportMenu = Wx::Menu.new
      @Controller.getExportPlugins.each do |iExportID, iExportInfo|
        addMenuCommand(lExportMenu, ID_EXPORT_BASE + iExportInfo[:PluginIndex]) do |iEvent, oValidator|
          oValidator.authorizeCmd(
            :parentWindow => self
          )
        end
      end
      lFileMenu.append_sub_menu(lExportMenu, 'Export')
      lFileMenu.append_separator
      addMenuCommand(lFileMenu, Wx::ID_CLOSE) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :instancesToClose => [ self ]
        )
      end
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
      @Controller.getTypesPlugins.each do |iTypeID, iTypeInfo|
        addMenuCommand(@NewShortcutMenu, ID_NEW_SHORTCUT_BASE + iTypeInfo[:PluginIndex]) do |iEvent, oValidator|
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
      @Controller.getShortcutCommandsPlugins.each do |iPluginID, iPluginInfo|
        addMenuCommand(@ShortcutCommandsMenu, ID_SHORTCUT_COMMAND_BASE + iPluginInfo[:PluginIndex]) do |iEvent, oValidator|
          # Here, we are sure the selection accepts this command
          lSelection = @TCMainTree.getCurrentSelection
          # Set of selected Shortcuts
          # map< Shortcut, nil >
          lSelectedShortcuts = {}
          (lSelection.SelectedPrimaryShortcuts + lSelection.SelectedSecondaryShortcuts).each do |iSelectedShortcutInfo|
            iSelectedShortcut, iParentTag = iSelectedShortcutInfo
            lSelectedShortcuts[iSelectedShortcut] = nil
          end
          # And now call the command for each Shortcut that is filtered by the :ShortcutTypes attribute of the plugin
          lShortcutsList = []
          lSelectedShortcuts.each do |iShortcut, iNil|
            if ((iPluginInfo[:ShortcutTypes] == nil) or
                (iPluginInfo[:ShortcutTypes].include?(iShortcut.Type.pluginDescription[:PluginName])))
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
      lIntPluginsSubMenu = Wx::Menu.new
      # For each integration plugin, add a menu item
      @Controller.getIntegrationPlugins.each do |iPluginName, iPluginInfo|
        addMenuCommand(lIntPluginsSubMenu, ID_INTEGRATION_INSTANCE_BASE + iPluginInfo[:PluginIndex])
      end
      lToolsMenu.append_sub_menu(lIntPluginsSubMenu, 'Instantiate a new view on Root')
      @ViewsSubMenu = Wx::Menu.new
      @Controller.registerViewsMenu(self, @ViewsSubMenu)
      lToolsMenu.append_sub_menu(@ViewsSubMenu, 'Instantiate a new view')
      lToolsMenu.append_separator
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
          :parentWindow => self,
          :PBSRootDir => @Controller.PBSRootDir
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
        Wx::ID_SAVE,
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

      # Set the main tree context menu
      @TCMainTree.setContextMenu(@EditMenu)

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

      # Update menus from start
      onMainTreeSelectionUpdated
      
    end

    # Unregister everything that might be referenced.
    # This is called just before destruction.
    def unregisterAll
      # The main tree
      @Controller.unregisterGUI(@TCMainTree)
      # The menus
      @Controller.unregisterMenuEvt(self)
      # The views menu
      @Controller.unregisterViewsMenu(self, @ViewsSubMenu)
      # The toolbars
      @Controller.unregisterToolbar(@ToolBar)
    end

    # Stop remaining timers and wait for them to be safely removed
    def killTimers
      @TCMainTree.killTimers
    end

  end

end
