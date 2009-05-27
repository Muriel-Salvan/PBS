#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Model/Model.rb'
require 'Tools.rb'
require 'Controller/Actions.rb'
require 'Controller/Notifiers.rb'
require 'Controller/GUIHelpers.rb'
require 'Controller/Readers.rb'
require 'Controller/UndoableAtomicOperations.rb'

module PBS

  # Define constants for commands that are not among predefined Wx ones
  ID_OPEN_MERGE = 1000
  ID_NEW_TAG = 1001
  ID_TAGS_EDITOR = 1002
  ID_TYPES_CONFIG = 1003
  ID_KEYMAPS = 1004
  ID_ENCRYPTION = 1005
  ID_TOOLBARS = 1006
  ID_STATS = 1007
  ID_DEVDEBUG = 1008
  # Following constants are base integers for plugins related commands. WxRuby takes 5000 - 6000 range.
  ID_IMPORT_BASE = 6000
  ID_IMPORT_MERGE_BASE = 7000
  ID_EXPORT_BASE = 8000
  ID_NEW_SHORTCUT_BASE = 9000
  ID_INTEGRATION_BASE = 10000

  # This class stores session information, and relays info from model to gui.
  # * Stores the main data (Shortcuts/Tags)
  # * Handles Undo/Redo management.
  # * Provide notifiers for data changes
  class Controller

    include Tools

    # Module defining possible Actions for Commands
    include Actions
    # Module defining possible Readers for Commands
    include Readers
    # Module defining GUI helpers
    include GUIHelpers
    # Module defining Notifiers
    include Notifiers
    # Module defining UAO
    include UndoableAtomicOperations

    # This class is given to each GUI callback that wants to invoke some commands.
    # Developers of GUI plugins can use it to give GUI dependent parameters to the generic commands.
    class CommandValidator

      # The parameters given to the command.
      # It can be nil if the command is not authorized to be performed.
      #   map< Symbol, Object >
      attr_reader :Params

      # An eventual error message to display if the command is not authorized.
      #   String
      attr_reader :Error

      # Constructor
      def initialize
        @Params = nil
        @Error = nil
      end

      # Set parameters for a command invocation
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters
      def authorizeCmd(iParams)
        @Params = iParams
      end

      # Set an error
      #
      # Parameters:
      # * *iError* (_String_): The error message
      def setError(iError)
        @Error = iError
      end

    end

    # Class storing information about undoable operations.
    # Basically it is a list of UndoableAtomicOperations, grouped with a title.
    class UndoableOperation

      # Title of the Undoable opersation
      #   String
      attr_accessor :Title

      # List of the atomic modifications
      #   list< UndoableAtomicOperation >
      attr_accessor :AtomicOperations

      # Constructor
      #
      # Parameters:
      # * *iTitle* (_String_): The title of the undoable operation
      def initialize(iTitle)
        @Title = iTitle
        @AtomicOperations = []
      end

      # Undo this operation
      def undo
        @AtomicOperations.reverse_each do |iAtomicOperation|
          iAtomicOperation.undoOperation
        end
      end

      # Redo this operation
      def redo
        @AtomicOperations.each do |iAtomicOperation|
          iAtomicOperation.doOperation
        end
      end

    end

    # Method that sends notifications to registered GUIs that implement desired methods
    #
    # Parameters:
    # * *iMethod* (_Symbol_): The method to call in the registered GUIs
    # * *iParams* (<em>list<Object></em>): Parameters to give the method
    def notifyRegisteredGUIs(iMethod, *iParams)
      puts "Notify GUIs for #{iMethod.to_s}"
      @RegisteredGUIs.each do |iRegisteredGUI|
        if (iRegisteredGUI.respond_to?(iMethod))
          iRegisteredGUI.send(iMethod, *iParams)
        end
      end
    end

    # Register a new GUI to be notified upon events
    #
    # Parameters:
    # * *iGUI* (_Object_): The GUI to be notified.
    def registerGUI(iGUI)
      @RegisteredGUIs << iGUI
    end

    # Register Integration plugins
    def registerIntegrationPluginsGUIs
      @IntegrationPlugins.each do |iName, iPlugin|
        registerGUI(iPlugin)
      end
    end

    # Set the visible properties of a Menu Item.
    # The method also inserts the menu item in its menu, as it appears some properties can not be set before insertion (like enabled), and others can not be made after (like bitmap).
    #
    # Parameters:
    # * *ioMenuItem* (<em>Wx::MenuItem</em>): The menu item
    # * *iCommandID* (_Integer_): The corresponding command ID
    # * *iMenuItemPos* (_Integer_): The position to insert the new menu item into the menu
    # * *oMenu* (<em>Wx::Menu</em>): The menu in which we insert the menu item
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *iFetchParametersCode* (_Proc_): Code to be called to fetch parameters (or nil if none needed)
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    def setMenuItemAppearanceWhileInsert(ioMenuItem, iCommandID, iMenuItemPos, oMenu, iEvtWindow, iFetchParametersCode, iParams = {})
      lCommand = @Commands[iCommandID]
      lTitle = lCommand[:title]
      if (iParams[:GUITitle] != nil)
        lTitle = iParams[:GUITitle]
      end
      if (lCommand[:accelerator] != nil)
        lTitle += "\t#{getStringForAccelerator(lCommand[:accelerator])}"
      end
      ioMenuItem.text = lTitle
      ioMenuItem.help = lCommand[:help]
      ioMenuItem.bitmap = lCommand[:bitmap]
      # Insert it
      oMenu.insert(iMenuItemPos, ioMenuItem)
      lEnabled = ((lCommand[:enabled]) and
                  ((iParams[:GUIEnabled] == nil) or
                   (iParams[:GUIEnabled])))
      if (!lEnabled)
        # We enable it this way, as using lNewMenuItem.enable works only half (bug ?)
        oMenu.enable(iCommandID, false)
      end
      # Set its event
      if (self.methods.include?(lCommand[:method].to_s))
        iEvtWindow.evt_menu(ioMenuItem) do |iEvent|
          # If a block has been given, call the command validator
          if (iFetchParametersCode != nil)
            lValidator = CommandValidator.new
            iFetchParametersCode.call(iEvent, lValidator)
            if (lValidator.Params != nil)
              # Call the command method with the parameters given by the validator
              send(lCommand[:method], lValidator.Params)
            elsif (lValidator.Error != nil)
              puts "!!! #{lValidator.Error}"
            else
              puts '!!! The Command Validator did not return any error, and did not set any parameters either. Skipping the command.'
            end
          else
            # Call the command method without parameters
            send(lCommand[:method])
          end
        end
      else
        iEvtWindow.evt_menu(ioMenuItem) do |iEvent|
          Wx::MessageDialog.new(nil,
              "This command (#{lTitle}) has not yet been implemented. Sorry.",
              :caption => 'Not yet implemented',
              :style => Wx::OK|Wx::ICON_EXCLAMATION
            ).show_modal
        end
      end
    end

    # Update the appearance of a menu item based on a command.
    # !!! This method deletes the current menu item and inserts a new one at the same position. Otherwise, changing properties of menu items results in buggy behaviour.
    #
    # Parameters:
    # * *ioMenuItem* (<em>Wx::MenuItem</em>): The menu item to update
    # * *iCommand* (<em>map<Symbol,Object></em>): The command
    # * *iEvtWindow* (<em>Wx::EvtHandler</em>): The event handler that will receive the command
    # * *iFetchParametersCode* (_Proc_): Code to be called to fetch parameters (or nil if none needed)
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    # ** *GUIEnabled* (_Boolean_): Does the GUI enable this item specifically ?
    # ** *GUITitle* (_String_): Override title if not nil
    def updateMenuItemAppearance(ioMenuItem, iCommand, iEvtWindow, iFetchParametersCode, iParams = {})
      lMenu = ioMenuItem.menu
      lCommandID = ioMenuItem.get_id
      # To update, we are going to remove the old MenuItem and add a new one. This is due because just updating the item normally messes up the bitmap and shortcuts (don't know why still ... bug ?)
      # Find the position of the menu item inside the menu
      # !!! Do not rely on the MenuItem object itself, as it appears that they are recreated on-the-fly without reason (bug ?). Instead of that, rely on the ID.
      lMenuItemPos = 0
      lMenu.menu_items.each do |iMenuItem|
        if (iMenuItem.get_id == lCommandID)
          break
        end
        lMenuItemPos += 1
      end
      # Delete the old MenuItem from the menu and the registered items
      lMenu.delete(lCommandID)
      iCommand[:registeredMenuItems].delete_if do |iMenuItemInfo|
        iMenuItem, iEvtWindow, iParametersCode, iAdditionalParams = iMenuItemInfo
        ioMenuItem == iMenuItem
      end
      # Create the new one and register it
      lNewMenuItem = Wx::MenuItem.new(lMenu, lCommandID)
      iCommand[:registeredMenuItems] << [ lNewMenuItem, iEvtWindow, iFetchParametersCode, iParams ]
      # Fill its attributes (do it at the same time it is inserted as otherwise bitmaps are ignored ... bug ?)
      setMenuItemAppearanceWhileInsert(lNewMenuItem, lCommandID, lMenuItemPos, lMenu, iEvtWindow, iFetchParametersCode, iParams)
    end

    # Find the GUI specific parameters of a registered menu item
    #
    # Parameters:
    # * *iMenu* (<em>Wx::Menu</em>): Menu to which the menu item belongs.
    # * *iCommandID* (_Integer_): The command ID of the menu item
    # * *CodeBlock*: The code to call once the menu item has been retrieved
    # ** *ioParams* (<em>map<Symbol,Object></em>): The parameters, free to be updated
    def findRegisteredMenuItemParams(iMenu, iCommandID)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        puts "!!! Unknown command of ID #{iCommandID}. Ignoring action."
      else
        # find the registered menu item
        lFound = false
        lCommand[:registeredMenuItems].each do |iMenuItemInfo|
          iMenuItem, iEvtWindow, iFetchParametersCode, iParams = iMenuItemInfo
          if ((iMenuItem.menu == iMenu) and
              (iMenuItem.get_id == iCommandID))
            # Found it
            lOldParams = iParams.clone
            yield(iParams)
            if (lOldParams != iParams)
              # Update the appearance
              updateMenuItemAppearance(iMenuItem, lCommand, iEvtWindow, iFetchParametersCode, iParams)
            end
            lFound = true
          end
        end
        if (!lFound)
          puts "!!! Failed to retrieve the registered menu item for command ID #{iCommandID} under menu #{iMenu}. Bug ?"
        end
      end
    end

    # Update the appearance of a toolbar button based on a command
    #
    # Parameters:
    # * *ioToolbarButton* (<em>Wx::ToolBarTool</em>): The toolbar button to update
    # * *iCommand* (<em>map<Symbol,Object></em>: The command's parameters
    # * *iParams* (<em>map<Symbol,Object></em>): Additional properties, specific to this command item [optional = {}]
    # ** *GUIEnabled* (_Boolean_): Does the GUI enable this item specifically ?
    # ** *GUITitle* (_String_): Override title if not nil
    def updateToolbarButtonAppearance(iToolbarButton, iCommand, iParams = {})
      lToolbar = iToolbarButton.tool_bar
      lCommandID = iToolbarButton.id
      lTitle = iCommand[:title]
      if (iParams[:GUITitle] != nil)
        lTitle = iParams[:GUITitle]
      end
      if (iCommand[:accelerator] != nil)
        lTitle += " (#{getStringForAccelerator(iCommand[:accelerator])})"
      end
      lToolbar.set_tool_normal_bitmap(lCommandID, iCommand[:bitmap])
      lToolbar.set_tool_short_help(lCommandID, lTitle)
      lToolbar.set_tool_long_help(lCommandID, iCommand[:help])
      lEnabled = ((iCommand[:enabled]) and
                  ((iParams[:GUIEnabled] == nil) or
                   (iParams[:GUIEnabled])))
      lToolbar.enable_tool(lCommandID, lEnabled)
    end

    # Find parameters associated to a registered toolbar button
    #
    # Parameters:
    # * *iToolbarButton* (<em>Wx::ToolbarTool</em>): The toolbar button
    # * *iCommandID* (_Integer_): ID of the command to add
    # * *CodeBlock*: The code to call once the menu item has been retrieved
    # ** *ioParams* (<em>map<Symbol,Object></em>): The parameters, free to be updated
    def findRegisteredToolbarButtonParams(iToolbarButton, iCommandID)
      lCommand = @Commands[iCommandID]
      if (lCommand == nil)
        puts "!!! Unknown command of ID #{iCommandID}. Ignoring action."
      else
        # Find the toolbar button
        lFound = false
        lCommand[:registeredToolbarButtons].each do |iToolbarButtonInfo|
          iRegisteredToolbarButton, iParams = iToolbarButtonInfo
          if (iToolbarButton == iRegisteredToolbarButton)
            # Found it
            lOldParams = iParams.clone
            yield(iParams)
            if (lOldParams != iParams)
              # Update the appearance
              updateToolbarButtonAppearance(iToolbarButton, lCommand, iParams)
            end
            lFound = true
          end
        end
        if (!lFound)
          puts "!!! Failed to retrieve the registered toolbar button for command ID #{iCommandID}. Bug ?"
        end
      end
    end

    # Update appearance of GUI components after changes in a command
    #
    # Parameters:
    # * *iCommandID* (_Integer_): The command ID that has been changed
    def updateImpactedAppearance(iCommandID)
      lCommandParams = @Commands[iCommandID]
      lCommandParams[:registeredMenuItems].each do |ioMenuItemInfo|
        ioMenuItem, iEvtWindow, iParametersCode, iAdditionalParams = ioMenuItemInfo
        updateMenuItemAppearance(ioMenuItem, lCommandParams, iEvtWindow, iParametersCode, iAdditionalParams)
      end
      lCommandParams[:registeredToolbarButtons].each do |ioToolbarButtonInfo|
        ioToolbarButton, iAdditionalParams = ioToolbarButtonInfo
        updateToolbarButtonAppearance(ioToolbarButton, lCommandParams, iAdditionalParams)
      end
    end

    # Give the possibility to update the description of a command, and update impacted GUI elements if necessary after.
    #
    # Parameters:
    # * *iCommandID* (_Integer_): The command iD
    # * *CodeBlock*: The code called to update the command
    # ** *ioCommand* (<em>map<Symbol,Object></em>): The command description, free to be updated
    def updateCommand(iCommandID)
      lCommand = @Commands[iCommandID]
      lOldCommand = lCommand.clone
      yield(lCommand)
      if (lCommand != lOldCommand)
        updateImpactedAppearance(iCommandID)
      end
    end

    # Command that launches the import plugin
    #
    # Parameters:
    # * *iImportID* (_String_): The import plugin ID
    # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
    # ** *iParentWindow* (<em>Wx::Window</em>): The parent window
    def cmdImport(iImportID, iParams)
      # Get the plugin
      @ImportPlugins[iImportID].execute(self, iParams[:parentWindow])
    end

    # Command that launches the import plugin and merges its result
    #
    # Parameters:
    # * *iImportID* (_String_): The import plugin ID
    # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
    # ** *iParentWindow* (<em>Wx::Window</em>): The parent window
    def cmdImportMerge(iImportID, iParams)
      # Note that it will be useless to ask for discard confirmation, as we will not discard anything
      @Merging = true
      # Get the plugin
      @ImportPlugins[iImportID].execute(self, iParams[:parentWindow])
      @Merging = false
    end

    # Constructor
    def initialize
      # Opened file context
      @CurrentOpenedFileName = nil
      @CurrentOpenedFileModified = false
      @Merging = false

      # Undo/Redo management
      @CurrentUndoableOperation = nil
      @UndoStack = []
      @RedoStack = []

      # Copy/Cut management
      @CopiedSelection = nil
      @CopiedMode = nil
      @CopiedID = nil

      # Plugins
      @TypesPlugins = readPlugins('Types')
      @ImportPlugins = readPlugins('Imports')
      @ExportPlugins = readPlugins('Exports')
      @IntegrationPlugins = readPlugins('Integration', self)
      @RegisteredGUIs = []

      # Create the commands info
      # This variable will contain every possible command that is then translated into menu items, toolbars, accelerators ...
      @Commands = {}
      # Controller Plugins: those plugins define modules that are included in the Controller.
      readControllerPlugins('Commands').each do |iCommandPluginName|
        eval("registerCmd#{iCommandPluginName}(@Commands)")
      end

      @Commands.merge!({
        Wx::ID_SAVE => {
          :title => 'Save',
          :help => 'Save current Shortcuts',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Save.png"),
          :method => :cmdSave, # TODO
          :accelerator => [ Wx::MOD_CMD, 's'[0] ]
        },
        Wx::ID_EXIT => {
          :title => 'Exit',
          :help => 'Quit PBS',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Exit.png"),
          :method => :cmdExit, # TODO
          :accelerator => nil
        },
        Wx::ID_FIND => {
          :title => 'Find',
          :help => 'Find a Shortcut',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Find.png"),
          :method => :cmdFind, # TODO
          :accelerator => [ Wx::MOD_CMD, 'f'[0] ]
        },
        ID_NEW_TAG => {
          :title => 'New Tag',
          :help => 'Create a new Tag',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdNewTag, # TODO
          :accelerator => nil
        },
        ID_TAGS_EDITOR => {
          :title => 'Tags Editor',
          :help => 'Edit the Tag\'s',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdTagsEditor, # TODO
          :accelerator => nil
        },
        ID_TYPES_CONFIG => {
          :title => 'Shortcuts\' Types configuration',
          :help => 'Configure the different Shortcut\'s Types',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Config.png"),
          :method => :cmdTypesConfig, # TODO
          :accelerator => nil
        },
        ID_KEYMAPS => {
          :title => 'Keymaps',
          :help => 'Configure key associations to commands',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdKeymaps, # TODO
          :accelerator => nil
        },
        ID_ENCRYPTION => {
          :title => 'Encryption',
          :help => 'Configure the encryption of PBS files',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdEncryption, # TODO
          :accelerator => nil
        },
        ID_TOOLBARS => {
          :title => 'Toolbars',
          :help => 'Configure buttons displayed in the toolbars',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdToolbars, # TODO
          :accelerator => nil
        },
        ID_STATS => {
          :title => 'Stats',
          :help => 'Give statistics on your Shortcuts use',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Stats.png"),
          :method => :cmdStats, # TODO
          :accelerator => nil
        },
        Wx::ID_HELP => {
          :title => 'User manual',
          :help => 'Display help file',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Help.png"),
          :method => :cmdHelp, # TODO
          :accelerator => nil
        },
        Wx::ID_ABOUT => {
          :title => 'About',
          :help => 'Give information about PBS',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdAbout, # TODO
          :accelerator => nil
        }
      })
      # Create commands for each import plugin
      @ImportPlugins.each do |iImportID, iImport|
        lTitle = iImport.getTitle
        @Commands[ID_IMPORT_BASE + iImport.index] = {
          :title => lTitle,
          :help => "Import Shortcuts from #{iImportID}",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => "cmdImport#{iImportID}".to_sym,
          :accelerator => nil
        }
        @Commands[ID_IMPORT_MERGE_BASE + iImport.index] = {
          :title => lTitle,
          :help => "Import Shortcuts from #{iImportID} and merge with existing",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => "cmdImportMerge#{iImportID}".to_sym,
          :accelerator => nil
        }
        eval("
def cmdImport#{iImportID}(iParams)
  cmdImport('#{iImportID}', iParams)
end
def cmdImportMerge#{iImportID}(iParams)
  cmdImportMerge('#{iImportID}', iParams)
end
")
      end
      # Create commands for each export plugin
      @ExportPlugins.each do |iExportID, iExport|
        @Commands[ID_EXPORT_BASE + iExport.index] = {
          :title => iExportID,
          :help => "Export Shortcuts to #{iImportID}",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Export.png"),
          :method => :cmdExport, # TODO
          :accelerator => nil
        }
      end
      # Create commands for each type plugin
      @TypesPlugins.each do |iTypeID, iType|
        @Commands[ID_NEW_SHORTCUT_BASE + iType.index] = {
          :title => iTypeID,
          :help => "Create a new Shortcut of type #{iTypeID}",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdNewShortcut, # TODO
          :accelerator => nil
        }
      end
      # Create commands for each integration plugin
      @IntegrationPlugins.each do |iIntID, iInt|
        @Commands[ID_INTEGRATION_BASE + iInt.index] = {
          :title => iIntID,
          :help => "Configure integration plugin #{iIntID}",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdIntegrationConfig, # TODO
          :accelerator => nil
        }
      end
      # Create dynamic attributes for @Commands
      @Commands.each do |iCommandID, iCommandParams|
        iCommandParams[:enabled] = true
        iCommandParams[:registeredMenuItems] = []
        iCommandParams[:registeredToolbarButtons] = []
      end

      # Create a sample data set
      # Tags
      @RootTag = Tag.new('Root', nil)
      lTag1 = Tag.new('Tag1', @RootTag)
      lTag1_1 = Tag.new('Tag1.1', lTag1)
      lTag1_2 = Tag.new('Tag1.2', lTag1)
      lTag2 = Tag.new('Tag2', @RootTag)

      # Shortcuts
      @ShortcutsList = [
        Shortcut.new(
          @TypesPlugins['URL'],
          { lTag1 => nil, lTag2 => nil },
          'www.google.com',
          { 'title' => 'Google' }
        ),
        Shortcut.new(
          @TypesPlugins['Shell'],
          { lTag1_1 => nil },
          'notepad',
          { 'title' => 'Bloc-notes' }
        ),
        Shortcut.new(
          @TypesPlugins['Shell'],
          {},
          'calc',
          { 'title' => 'Calculatrice' }
        ),
        Shortcut.new(
          @TypesPlugins['Shell'],
          { lTag1_1 => nil },
          'irb',
          { 'title' => 'Ruby' }
        )
      ]
    end

    # Read plugins that define modules to be included in the Controller
    #
    # Parameters:
    # * *iPluginsID* (_String_): The plugins identifier
    # Return:
    # * <em>list<String></em>: The list of plugin names included
    def readControllerPlugins(iPluginsID)
      rPluginsList = []

      # Read all commands that are present in the file system
      Dir.glob("#{$PBSRootDir}/Controller/#{iPluginsID}/*.rb").each do |iFileName|
        lPluginName = File.basename(iFileName)[0..-4]
        lRequireName = "Controller/#{iPluginsID}/#{lPluginName}.rb"
        begin
          require lRequireName
          begin
            # We include and register it
            self.class.module_eval("include #{iPluginsID}::#{lPluginName}")
            rPluginsList << lPluginName
          rescue Exception
            puts "!!! Error while including controller plugin (#{lRequireName}): #{$!}"
            puts "!!! Check that module PBS::#{iPluginsID}::#{lPluginName} has been correctly defined in it."
            puts '!!! This plugin will be ignored.'
            puts $!.backtrace.join("\n")
          end
        rescue Exception
          puts "!!! Error while loading one of the controller plugins (#{lRequireName}): #{$!}"
          puts '!!! This plugin will be ignored.'
          puts $!.backtrace.join("\n")
        end
      end

      return rPluginsList
    end

    # Read the plugins identified by a given ID, and return a map of the instantiated plugins.
    #
    # Parameters:
    # * *iPluginsID* (_String_): The plugins identifier
    # * *iParams* (<em>list<Object></em>): Additional parameters [optional]
    # Return:
    # * <em>map< String, Object ></em>: The map of retrieved plugins
    def readPlugins(iPluginsID, *iParams)
      # Get the different types
      # map< String, Object >
      rPlugins = {}
      lIdxPlugin = 0
      Dir.glob("#{$PBSRootDir}/#{iPluginsID}/*.rb").each do |iFileName|
        lPluginName = File.basename(iFileName)[0..-4]
        lRequireName = "#{iPluginsID}/#{lPluginName}.rb"
        begin
          require lRequireName
          begin
            lPlugin = eval("#{iPluginsID}::#{lPluginName}.new(*iParams)")
            rPlugins[lPluginName] = lPlugin
            # Create metadata on the plugin itself
            lPlugin.instance_eval("
def index
return #{lIdxPlugin}
end
def pluginName
return '#{lPluginName}'
end
")
            lIdxPlugin += 1
          rescue Exception
            puts "!!! Error while instantiating one of the #{iPluginsID} plugin (#{lRequireName}): #{$!}"
            puts "!!! Check that class PBS::#{iPluginsID}::#{lPluginName} has been correctly defined in it."
            puts '!!! This plugin will be ignored.'
            puts $!.backtrace.join("\n")
          end
        rescue Exception
          puts "!!! Error while loading one of the #{iPluginsID} plugin (#{lRequireName}): #{$!}"
          puts '!!! This plugin will be ignored.'
          puts $!.backtrace.join("\n")
        end
      end

      return rPlugins
    end

    # Ensure that we are in a current undoableOperation, and create a default one if not.
    #
    # Parameters:
    # * *iDefaultTitle* (_String_): Default title for the undoable operation
    def ensureUndoableOperation(iDefaultTitle)
      if (@CurrentUndoableOperation == nil)
        # Create a default undoable operation
        puts "!!! Operation \"#{iDefaultTitle}\" was not protected by undoableOperation, and it modifies some data. Create a default UndoableOperation."
        undoableOperation(iDefaultTitle) do
          yield
        end
      else
        yield
      end
    end

    # Set the Root Tag.
    # !!! This method has to be used only in the atomic operation replacing all the data
    #
    # Parameters:
    # * *iNewRootTag* (_Tag_): The new root Tag to set
    def setRootTag_UNDO(iNewRootTag)
      @RootTag = iNewRootTag
    end

    # Set the Shortcuts list.
    # !!! This method has to be used only in the atomic operation replacing all the data
    #
    # Parameters:
    # * *iNewShortcutsList* (<em>list<Shortcut></em>): The new Shortcuts list to set
    def setShortcutsList_UNDO(iNewShortcutsList)
        @ShortcutsList = iNewShortcutsList
    end

    # Set the current opened file name.
    # !!! This method has to be used only in the atomic operation replacing all the data
    #
    # Parameters:
    # * *iNewFileName* (_String_): New file name
    def setCurrentOpenedFileName_UNDO(iNewFileName)
      @CurrentOpenedFileName = iNewFileName
    end

    # Set the current opened file modified flag
    # !!! This method has to be used only in the atomic operation replacing all the data
    #
    # Parameters:
    # * *iNewFileModified* (_Boolean_): The flag
    def setCurrentOpenedFileModified_UNDO(iNewFileModified)
      @CurrentOpenedFileModified = iNewFileModified
    end

    # Add a new Shortcut
    # !!! This method has to be used only in the atomic operation adding new Shortcuts
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut to add
    def addShortcut_UNDO(iSC)
      @ShortcutsList << iSC
    end
    
    # Delete a Shortcut
    # !!! This method has to be used only in the atomic operation adding new Shortcuts
    #
    # Parameters:
    # * *iSCID* (_Integer_): The Shortcut ID to delete
    def deleteShortcut_UNDO(iSCID)
      @ShortcutsList.delete_if do |iSC|
        iSC.getUniqueID == iSCID
      end
    end

    # Dump a Tag
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to dump
    # * *iPrefix* (_String_): Prefix of each dump line [optional = '']
    # * *iLastItem* (_Boolean_): Is this item the last one of the list it belongs to ? [optional = true]
    def dumpTag(iTag, iPrefix = '', iLastItem = true)
      puts "#{iPrefix}+-#{iTag.Name} (@#{iTag.object_id})"
      if (iLastItem)
        lChildPrefix = "#{iPrefix}  "
      else
        lChildPrefix = "#{iPrefix}| "
      end
      lIdx = 0
      iTag.Children.each do |iChildTag|
        dumpTag(iChildTag, lChildPrefix, lIdx == iTag.Children.size - 1)
        lIdx += 1
      end
    end

    # Dump a Shortcuts list
    #
    # Parameters:
    # * *iShortcutsList* (<em>list<Shortcut></em>): The Shortcuts list to dump
    def dumpShortcutsList(iShortcutsList)
      iShortcutsList.each do |iSC|
        puts "=== #{iSC.Metadata['title']} (@#{iSC.object_id})"
        puts "  = ID: #{iSC.getUniqueID}"
        puts "  = Type: #{iSC.Type.inspect}"
        puts "  = Metadata: #{iSC.Metadata.inspect}"
        puts "  = Content: #{iSC.Content.inspect}"
        puts "  = #{iSC.Tags.size} Tags:"
        iSC.Tags.each do |iTag, iNil|
          puts "  = - #{iTag.Name}: ID #{iTag.getUniqueID.join('/')} (@#{iTag.object_id})"
        end
      end
    end

  end

end
