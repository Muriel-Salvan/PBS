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
  ID_EDIT_SHORTCUT = 1001
  ID_NEW_TAG = 1002
  ID_EDIT_TAG = 1003
  ID_TAGS_EDITOR = 1004
  ID_TYPES_CONFIG = 1005
  ID_KEYMAPS = 1006
  ID_ENCRYPTION = 1007
  ID_TOOLBARS = 1008
  ID_STATS = 1009
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
    def setMenuItemAppearanceWhileInsert(ioMenuItem, iCommandID, iMenuItemPos, oMenu, iEvtWindow, iFetchParametersCode)
      lCommand = @Commands[iCommandID]
      lTitle = lCommand[:title]
      if (lCommand[:accelerator] != nil)
        lTitle += "\t#{getStringForAccelerator(lCommand[:accelerator])}"
      end
      ioMenuItem.text = lTitle
      ioMenuItem.help = lCommand[:help]
      ioMenuItem.bitmap = lCommand[:bitmap]
      # Insert it
      oMenu.insert(iMenuItemPos, ioMenuItem)
      if (!lCommand[:enabled])
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
    def updateMenuItemAppearance(ioMenuItem, iCommand, iEvtWindow, iFetchParametersCode)
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
        iMenuItem, iEvtWindow, iParametersCode = iMenuItemInfo
        ioMenuItem == iMenuItem
      end
      # Create the new one and register it
      lNewMenuItem = Wx::MenuItem.new(lMenu, lCommandID)
      iCommand[:registeredMenuItems] << [ lNewMenuItem, iEvtWindow, iFetchParametersCode ]
      # Fill its attributes (do it at the same time it is inserted as otherwise bitmaps are ignored ... bug ?)
      setMenuItemAppearanceWhileInsert(lNewMenuItem, lCommandID, lMenuItemPos, lMenu, iEvtWindow, iFetchParametersCode)
    end

    # Update the appearance of a toolbar button based on a command
    #
    # Parameters:
    # * *ioToolbarButton* (<em>Wx::ToolBarTool</em>): The toolbar button to update
    # * *iCommand* (<em>map<Symbol,Object></em>: The command's parameters
    def updateToolbarButtonAppearance(iToolbarButton, iCommand)
      lToolbar = iToolbarButton.tool_bar
      lCommandID = iToolbarButton.id
      lTitle = iCommand[:title]
      if (iCommand[:accelerator] != nil)
        lTitle += " (#{getStringForAccelerator(iCommand[:accelerator])})"
      end
      lToolbar.set_tool_normal_bitmap(lCommandID, iCommand[:bitmap])
      lToolbar.set_tool_short_help(lCommandID, lTitle)
      lToolbar.set_tool_long_help(lCommandID, iCommand[:help])
      lToolbar.enable_tool(lCommandID, iCommand[:enabled])
    end

    # Update appearance of GUI components after changes in a command
    #
    # Parameters:
    # * *iCommandID* (_Integer_): The command ID that has been changed
    def updateImpactedAppearance(iCommandID)
      lCommandParams = @Commands[iCommandID]
      lCommandParams[:registeredMenuItems].each do |ioMenuItemInfo|
        ioMenuItem, iEvtWindow, iParametersCode = ioMenuItemInfo
        updateMenuItemAppearance(ioMenuItem, lCommandParams, iEvtWindow, iParametersCode)
      end
      lCommandParams[:registeredToolbarButtons].each do |ioToolbarButton|
        updateToolbarButtonAppearance(ioToolbarButton, lCommandParams)
      end
    end

    # Constructor
    def initialize
      # Opened file context
      @CurrentOpenedFileName = nil
      @CurrentOpenedFileModified = false

      # Undo/Redo management
      @CurrentUndoableOperation = nil
      @UndoStack = []
      @RedoStack = []

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
        Wx::ID_CUT => {
          :title => 'Cut',
          :help => 'Cut selection',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Cut.png"),
          :method => :cmdCut, # TODO
          :accelerator => [ Wx::MOD_CMD, 'x'[0] ]
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
        ID_EDIT_TAG => {
          :title => 'Edit Tag',
          :help => 'Edit the selected Tag\'s parameters',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdEditTag, # TODO
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
        @Commands[ID_IMPORT_BASE + iImport.index] = {
          :title => iImportID,
          :help => "Import Shortcuts from #{iImportID}",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdImport, # TODO
          :accelerator => nil
        }
        @Commands[ID_IMPORT_MERGE_BASE + iImport.index] = {
          :title => iImportID,
          :help => "Import Shortcuts from #{iImportID} and merge with existing",
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Image1.png"),
          :method => :cmdImportMerge, # TODO
          :accelerator => nil
        }
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

  end

end
