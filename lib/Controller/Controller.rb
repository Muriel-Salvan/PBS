#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Controller/Actions.rb'
require 'Controller/Notifiers.rb'
require 'Controller/GUIHelpers.rb'
require 'Controller/Readers.rb'
require 'Controller/UndoableAtomicOperations.rb'
require 'Windows/ResolveTagConflictDialog.rb'
require 'Windows/ResolveShortcutConflictDialog.rb'
require 'Windows/DependenciesLoaderDialog.rb'

module PBS

  # Define constants for commands that are not among predefined Wx ones
  # WxRuby takes 5000 - 6000 range.
  # TODO (WxRuby): Use an ID generator
  ID_OPEN_MERGE = 1000
  ID_NEW_TAG = 1001
  ID_STATS = 1002
  ID_DEVDEBUG = 1003
  # Following constants are used in dialogs (for Buttons IDs and so return values)
  ID_MERGE_EXISTING = 2000
  ID_MERGE_CONFLICTING = 2001
  ID_KEEP = 2002
  # Following constants are base integers for plugins related commands.
  ID_IMPORT_BASE = 6000
  ID_IMPORT_MERGE_BASE = 7000
  ID_EXPORT_BASE = 8000
  ID_NEW_SHORTCUT_BASE = 9000

  # Following constants are used in options
  TAGSUNICITY_NONE = 0
  TAGSUNICITY_NAME = 1
  TAGSUNICITY_ALL = 2
  SHORTCUTSUNICITY_NONE = 0
  SHORTCUTSUNICITY_NAME = 1
  SHORTCUTSUNICITY_CONTENT = 2
  SHORTCUTSUNICITY_METADATA = 3
  SHORTCUTSUNICITY_ALL = 4
  TAGSCONFLICT_ASK = 0
  TAGSCONFLICT_MERGE_EXISTING = 1
  TAGSCONFLICT_MERGE_CONFLICTING = 2
  TAGSCONFLICT_CANCEL = 3
  TAGSCONFLICT_CANCEL_ALL = 4
  SHORTCUTSCONFLICT_ASK = 0
  SHORTCUTSCONFLICT_MERGE_EXISTING = 1
  SHORTCUTSCONFLICT_MERGE_CONFLICTING = 2
  SHORTCUTSCONFLICT_CANCEL = 3
  SHORTCUTSCONFLICT_CANCEL_ALL = 4

  # Global constants
  # Number of errors showing in a single dialog
  MAX_ERRORS_PER_DIALOG = 10

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

    # Class used to factorize import commands
    class ImportCommand

      include Tools

      # Constructor
      #
      # Parameters:
      # * *iImportPluginName* (_String_): The import plugin ID
      # * *iMerge* (_Boolean_): Do we instantiate a command that merges data ?
      def initialize(iImportPluginName, iMerge)
        @ImportPluginName = iImportPluginName
        @Merge = iMerge
      end

      # Command that imports data from an import plugin
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window calling this plugin.
      def execute(ioController, iParams)
        if (@Merge)
          ioController.Merging = true
        end
        # Protect with exception
        begin
          ioController.ImportPlugins[@ImportPluginName][:plugin].execute(ioController, iParams[:parentWindow])
        rescue Exception
          logBug "Plugin Imports/#{@ImportPluginName} threw an exception: #{$!}\nException stack:\n#{$!.backtrace.join("\n")}"
        end
        if (@Merge)
          ioController.Merging = false
        end
      end

    end

    # Class used to factorize export commands
    class ExportCommand

      include Tools

      # Constructor
      #
      # Parameters:
      # * *iExportPluginName* (_String_): The export plugin ID
      def initialize(iExportPluginName)
        @ExportPluginName = iExportPluginName
      end

      # Command that exports data to an export plugin
      #
      # Parameters:
      # * *iController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window calling this plugin.
      def execute(iController, iParams)
        begin
          iController.ExportPlugins[@ExportPluginName][:plugin].execute(iController, iParams[:parentWindow])
        rescue Exception
          logBug "Plugin Exports/#{@ImportPluginName} threw an exception: #{$!}\nException stack:\n#{$!.backtrace.join("\n")}"
        end
      end

    end

    # Class used to factorize new Shortcut commands
    class NewShortcutCommand

      include Tools

      # Constructor
      #
      # Parameters:
      # * *iTypePluginName* (_String_): The type plugin ID
      def initialize(iTypePluginName)
        @TypePluginName = iTypePluginName
      end

      # Command that creates a new Shortcut via the corresponding Type plugin
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *tag* (_Tag_): Tag in which we create the new Tag (can be nil for no Tag)
      # ** *parentWindow* (<em>Wx::Window</em>): The parent window calling this plugin.
      def execute(ioController, iParams)
        lWindow = iParams[:parentWindow]
        lTag = iParams[:tag]
        lShortcutTypeInfo = ioController.TypesPlugins[@TypePluginName]
        if (lShortcutTypeInfo == nil)
          logBug "Shortcut Type #{@TypePluginName} should have been registered, but unable to retrieve it."
        else
          lLocationName = ''
          if (lTag != nil)
            lLocationName = " in #{lTag.Name}"
          end
          ioController.undoableOperation("Create new Shortcut#{lLocationName}") do
            showModal(EditShortcutDialog, lWindow, nil, ioController.RootTag, ioController, lShortcutTypeInfo[:plugin], lTag) do |iModalResult, iDialog|
              case iModalResult
              when Wx::ID_OK
                lNewContent, lNewMetadata, lNewTags = iDialog.getData
                ioController.createShortcut(@TypePluginName, lNewContent, lNewMetadata, lNewTags)
              end
            end
          end
        end
      end

    end

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
      attr_reader :Title

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

    # Do we merge the next command launched ?
    #   Boolean
    attr_accessor :Merging

    # Test if a given data does not violate unicity constraints for a Tag if it was to be added
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The parent Tag
    # * *iTagName* (_String_): The new Tag name
    # * *iIcon* (<em>Wx::Bitmap</em>): The icon (can be nil)
    # * *iTagToIgnore* (_Tag_): The Tag to ignore in unicity checking (useful when editing: we don't match unicity with the already existing object). Can be nil to check all sub-Tags. [optional = nil]
    # Return:
    # * _Tag_: Tag that is a doublon of the data given, or nil otherwise.
    # * _Integer_: Action taken in case of doublon, or nil otherwise
    # * _String_: The new Tag name to consider
    # * <em>Wx::Bitmap</em>: The new icon to consider
    def checkTagUnicity(iParentTag, iTagName, iIcon, iTagToIgnore = nil)
      rDoublon = nil
      rAction = nil
      rNewTagName = iTagName
      rNewIcon = iIcon

      # If it was asked before to always keep both Tags in case of conflict, don't even bother
      if (@CurrentOperationTagsConflicts != ID_KEEP)
        iParentTag.Children.each do |ioChildTag|
          if ((ioChildTag != iTagToIgnore) and
              (tagSameAs?(ioChildTag, iTagName, iIcon)))
            rDoublon = ioChildTag
            # It already exists. Check options to know what to do.
            if ((@Options[:tagsConflict] == TAGSCONFLICT_ASK) and
                (@CurrentOperationTagsConflicts == nil))
              # Ask for replacement or cancellation
              showModal(ResolveTagConflictDialog, nil, ioChildTag, iTagName, iIcon) do |iModalResult, iDialog|
                rAction = iModalResult
                if (iDialog.applyToAll?)
                  @CurrentOperationTagsConflicts = rAction
                end
                case iModalResult
                when ID_MERGE_EXISTING, ID_MERGE_CONFLICTING
                  # Take values from the dialog, and put them into the existing Tag
                  lName, lIcon = iDialog.getData
                  updateTag(ioChildTag, lName, lIcon, ioChildTag.Children)
                when ID_KEEP
                  rNewTagName, rNewIcon = iDialog.getData
                end
              end
            elsif ((@Options[:tagsConflict] == TAGSCONFLICT_MERGE_EXISTING) or
                   (@CurrentOperationTagsConflicts == ID_MERGE_EXISTING))
              rAction = ID_MERGE_EXISTING
            elsif ((@Options[:tagsConflict] == TAGSCONFLICT_MERGE_CONFLICTING) or
                   (@CurrentOperationTagsConflicts == ID_MERGE_CONFLICTING))
              updateTag(ioChildTag, iTagName, iIcon, ioChildTag.Children)
              rAction = ID_MERGE_CONFLICTING
            elsif ((@Options[:tagsConflict] == TAGSCONFLICT_CANCEL) or
                   (@CurrentOperationTagsConflicts == Wx::ID_CANCEL))
              @CurrentTransactionErrors << "Tags conflict between #{ioChildTag.Name} and #{iTagName}."
              rAction = Wx::ID_CANCEL
            elsif (@Options[:tagsConflict] == TAGSCONFLICT_CANCEL_ALL)
              @CurrentTransactionErrors << "Tags conflict between #{ioChildTag.Name} and #{iTagName}."
              @CurrentTransactionToBeCancelled = true
              rAction = Wx::ID_CANCEL
            else
              logBug "Unknown decision to take concerning a Tags conflict: the option :tagsConflict is #{@Options[:tagsConflict]}, and the user decision to always apply is #{@CurrentOperationTagsConflicts}."
            end
          end
        end
      end

      return rDoublon, rAction, rNewTagName, rNewIcon
    end

    # Test if a given data does not violate unicity constraints for a Shortcut if it was to be added
    #
    # Parameters:
    # * *iType* (_ShortcutType_): The type
    # * *iContent* (_Object_): The content
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # * *iTags* (<em>map<Tag,nil></em>): The set of Tags
    # * *iShortcutToIgnore* (_Shortcut_): The Shortcut to ignore in unicity checking (useful when editing: we don't match unicity with the already existing object). Can be nil to check all Shortcuts. [optional = nil]
    # Return:
    # * _Shortcut_: Shortcut that is a doublon of the data given, or nil otherwise.
    # * _Integer_: Action taken in case of doublon, or nil otherwise
    # * _Object_: The new content to consider
    # * <em>map<String,Object></em>: The new metadata to consider
    def checkShortcutUnicity(iType, iContent, iMetadata, iTags, iShortcutToIgnore = nil)
      rDoublon = nil
      rAction = nil
      rNewContent = iContent
      rNewMetadata = iMetadata

      # If it was asked before to always keep both Shortcuts in case of conflict, don't even bother
      if (@CurrentOperationShortcutsConflicts != ID_KEEP)
        @ShortcutsList.each do |ioSC|
          if ((ioSC != iShortcutToIgnore) and
              (ioSC.Type == iType) and
              (shortcutSameAs?(ioSC,  iContent, iMetadata)))
            rDoublon = ioSC
            # It already exists. Check options to know what to do.
            if ((@Options[:shortcutsConflict] == SHORTCUTSCONFLICT_ASK) and
                (@CurrentOperationShortcutsConflicts == nil))
              showModal(ResolveShortcutConflictDialog, nil, ioSC, iContent, iMetadata, self) do |iModalResult, iDialog|
                rAction = iModalResult
                if (iDialog.applyToAll?)
                  @CurrentOperationShortcutsConflicts = rAction
                end
                case iModalResult
                when ID_MERGE_EXISTING, ID_MERGE_CONFLICTING
                  # Take values from the dialog, then modify the current Shortcut
                  lContent, lMetadata = iDialog.getData
                  lNewTags = iTags.clone
                  lNewTags.merge!(ioSC.Tags)
                  updateShortcut(ioSC, lContent, lMetadata, lNewTags)
                when ID_KEEP
                  rNewContent, rNewMetadata = iDialog.getData
                end
              end
            elsif ((@Options[:shortcutsConflict] == SHORTCUTSCONFLICT_MERGE_EXISTING) or
                   (@CurrentOperationShortcutsConflicts == ID_MERGE_EXISTING))
              lNewTags = iTags.clone
              lNewTags.merge!(rDoublon.Tags)
              updateShortcut(rDoublon, rDoublon.Content, rDoublon.Metadata, lNewTags)
              rAction = ID_MERGE_EXISTING
            elsif ((@Options[:shortcutsConflict] == SHORTCUTSCONFLICT_MERGE_CONFLICTING) or
                   (@CurrentOperationShortcutsConflicts == ID_MERGE_CONFLICTING))
              lNewTags = iTags.clone
              lNewTags.merge!(ioSC.Tags)
              updateShortcut(ioSC, iContent, iMetadata, lNewTags)
              rAction = ID_MERGE_CONFLICTING
            elsif ((@Options[:shortcutsConflict] == SHORTCUTSCONFLICT_CANCEL) or
                   (@CurrentOperationShortcutsConflicts == Wx::ID_CANCEL))
              @CurrentTransactionErrors << "Shortcuts conflict between #{ioSC.Metadata['title']} and #{iMetadata['title']}."
              rAction = Wx::ID_CANCEL
            elsif (@Options[:shortcutsConflict] == SHORTCUTSCONFLICT_CANCEL_ALL)
              @CurrentTransactionErrors << "Shortcuts conflict between #{ioSC.Metadata['title']} and #{iMetadata['title']}."
              @CurrentTransactionToBeCancelled = true
              rAction = Wx::ID_CANCEL
            else
              logBug "Unknown decision to take concerning a Shortcuts conflict: the option :shortcutsConflict is #{@Options[:shortutsConflict]}, and the user decision to always apply is #{@CurrentOperationShortcutsConflicts}."
            end
          end
        end
      end

      return rDoublon, rAction, rNewContent, rNewMetadata
    end

    # Method that sends notifications to registered GUIs that implement desired methods
    #
    # Parameters:
    # * *iMethod* (_Symbol_): The method to call in the registered GUIs
    # * *iParams* (<em>list<Object></em>): Parameters to give the method
    def notifyRegisteredGUIs(iMethod, *iParams)
      logDebug "Notify GUIs for #{iMethod.to_s}"
      @RegisteredGUIs.each do |iRegisteredGUI|
        if (iRegisteredGUI.respond_to?(iMethod))
          begin
            iRegisteredGUI.send(iMethod, *iParams)
          rescue Exception
            logBug "A notified GUI (maybe from an Integration Plugin) threw an exception: #{$!}\nException stack:\n#{$!.backtrace.join("\n")}"
          end
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
      @IntegrationPlugins.each do |iName, iPluginInfo|
        registerGUI(iPluginInfo[:plugin])
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
      ioMenuItem.help = lCommand[:description]
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
      iEvtWindow.evt_menu(ioMenuItem) do |iEvent|
        # If a block has been given, call the command validator
        if (iFetchParametersCode != nil)
          lValidator = CommandValidator.new
          iFetchParametersCode.call(iEvent, lValidator)
          if (lValidator.Params != nil)
            executeCommand(iCommandID, lValidator.Params)
          elsif (lValidator.Error != nil)
            logErr lValidator.Error
          else
            logBug 'The Command Validator did not return any error, and did not set any parameters either. Skipping the command.'
          end
        else
          executeCommand(iCommandID)
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
        logBug "Unknown command of ID #{iCommandID}. Ignoring action."
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
          logBug "Failed to retrieve the registered menu item for command ID #{iCommandID} under menu #{iMenu}."
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
      lToolbar.set_tool_long_help(lCommandID, iCommand[:description])
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
        logBug "Unknown command of ID #{iCommandID}. Ignoring action."
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
          logBug "Failed to retrieve the registered toolbar button for command ID #{iCommandID}."
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
      lOldCommand = nil
      if (lCommand == nil)
        logBug "Command #{iCommandID} is not registered. Check command plugins."
        # Provide an empty command for the code block to execute correctly.
        lCommand = {}
      else
        lOldCommand = lCommand.clone
      end
      yield(lCommand)
      if ((lOldCommand != nil) and
          (lCommand != lOldCommand))
        updateImpactedAppearance(iCommandID)
      end
    end

    # Constructor
    def initialize
      # Opened file context
      @CurrentOpenedFileName = nil
      @CurrentOpenedFileModified = false
      @Merging = false

      # Undo/Redo management
      # Controller::UndoableOperation
      @CurrentUndoableOperation = nil
      # list< Controller::UndoableOperation >
      @UndoStack = []
      # list< Controller::UndoableOperation >
      @RedoStack = []
      # list< String >
      @CurrentTransactionErrors = []
      # Boolean
      @CurrentTransactionToBeCancelled = false
      # Integer
      @CurrentOperationTagsConflicts = nil
      # Integer
      @CurrentOperationShortcutsConflicts = nil

      # Local Copy/Cut management
      @CopiedSelection = nil
      @CopiedMode = nil
      @CopiedID = nil

      # Clipboard content management
      # Those variables reflect what is inside the clipboard in real time.
      @Clipboard_CopyMode = nil
      @Clipboard_CopyID = nil
      @Clipboard_SerializedSelection = nil

      # Options
      # Fill this with the default options
      # map< Symbol, Object >
      @Options = {
        :tagsUnicity => TAGSUNICITY_NONE,
        :shortcutsUnicity => SHORTCUTSUNICITY_ALL,
        :tagsConflict => TAGSCONFLICT_ASK,
        :shortcutsConflict => SHORTCUTSCONFLICT_ASK,
        # The list of directories storing some libraries, per architecture
        # map< String, list< String > >
        :externalLibDirs => {}
      }

      # The GUIS registered
      # list< Object >
      @RegisteredGUIs = []

      # The plugins
      # map< String, map< Symbol, Object > >
      @TypesPlugins = {}
      @ImportPlugins = {}
      @ExportPlugins = {}
      @IntegrationPlugins = {}
      @CommandPlugins = {}

      # Create the base of the data model:
      # * The root Tag
      #   Tag
      @RootTag = Tag.new('Root', nil)
      # * The Shortcuts list
      #   list< Shortcut >
      @ShortcutsList = []

    end

    # Get the list of directories to parse for libraries (plugin dependencies).
    # Check for existence before return.
    # The list depends on options
    #
    # Return:
    # * <em>list<String></em>: The list of directories
    def getExternalLibDirs
      rList = getLocalExternalLibDirs

      # Every previously searched directory for this architecture
      if (@Options[:externalLibDirs][RUBY_PLATFORM] != nil)
        @Options[:externalLibDirs][RUBY_PLATFORM].each do |iDir|
          if (File.exists?("#{iDir}/lib"))
            rList << "#{iDir}/lib"
          end
        end
      end

      return rList.uniq
    end

    # Initialize the controller once the main_loop has been called
    # This lets messages pop up.
    def init
      # Add external libraries directories to the load path
      addToLoadPath(getExternalLibDirs)

      # Load plugins
      # Map keeping trace of missing dependencies: for each require name, the gem install command and the list of [ plugin type, plugin name, corresponding plugins map, constructor parameters ] that depend on this require.
      # map< String, [ String, list< [ String, String, map< String, map< Symbol, Object > >, list< Object > ] > ] >
      lMissingDeps = {}
      readPlugins(@TypesPlugins, 'Types', lMissingDeps)
      readPlugins(@ImportPlugins, 'Imports', lMissingDeps)
      readPlugins(@ExportPlugins, 'Exports', lMissingDeps)
      readPlugins(@IntegrationPlugins, 'Integration', lMissingDeps, self)
      readPlugins(@CommandPlugins, 'Commands', lMissingDeps)

      # Check missing deps
      if (!lMissingDeps.empty?)
        showModal(DependenciesLoaderDialog, nil, lMissingDeps) do |iModalResult, iDialog|
          # Get the list of additional directories to search into
          lExternalDirs = iDialog.getExternalDirectories
          # Store it for future use in options
          if (@Options[:externalLibDirs][RUBY_PLATFORM] == nil)
            @Options[:externalLibDirs][RUBY_PLATFORM] = []
          end
          @Options[:externalLibDirs][RUBY_PLATFORM].concat(lExternalDirs)
          # Replace the load path with the new external lib dirs
          addToLoadPath(getExternalLibDirs)
          # Get the list of dependencies that should be loadable
          lLoadableDeps = iDialog.getLoadableDependencies
          # Build the map of requires needed per plugin ( [ Plugin type ID, Plugin name ] ): the list of requires that need to be installed, and the corresponding plugins map to complete and parameters to give the constructor
          # map< [ String, String ], [ list< String >, map< String, map< Symbol, Object > >, list< Object > ] >
          lRequiresPerPlugin = {}
          lMissingDeps.each do |iRequireName, ioRequireInfo|
            iGemInstallCommand, iPluginsList = ioRequireInfo
            iPluginsList.each do |ioPluginInfo|
              iPluginTypeID, iPluginName, ioPluginsMap, iParams = ioPluginInfo
              lPluginID = [ iPluginTypeID, iPluginName ]
              if (lRequiresPerPlugin[lPluginID] == nil)
                lRequiresPerPlugin[lPluginID] = [ [], ioPluginsMap, iParams ]
              end
              lRequiresPerPlugin[lPluginID][0] << iRequireName
            end
          end
          # And now for each missing plugin that might become loadable, try to load it again
          lRequiresPerPlugin.each do |iPluginID, ioRequiresInfo|
            iPluginTypeID, iPluginName = iPluginID
            iRequiresList, ioPluginsMap, iParams = ioRequiresInfo
            # Check if all requires are loadable
            lPluginLoadable = true
            iRequiresList.each do |iRequireName|
              if (!lLoadableDeps.include?(iRequireName))
                # We can't load iPluginID, because iRequireName will still be missing
                logInfo "Plugin #{iPluginTypeID}/#{iPluginName} cannot be loaded due to missing require #{iRequireName}. Ignoring this plugin."
                lPluginLoadable = false
                break
              end
            end
            if (lPluginLoadable)
              # Try to reload it for real
              loadPlugin(ioPluginsMap, iPluginTypeID, iPluginName, *iParams)
            end
          end
        end
      end

      # Create the commands info
      # This variable maps each command ID with its info, including:
      # * :title (_String_): The title
      # * :description (_String_): The description
      # * :bitmap (<em>Wx::Bitmap</em>): The bitmap
      # * :accelerator (<em>[Integer,Integer]</em>): The accelerator key (Modifier and Key)
      # * :parameters (<em>list<Symbol></em>): The list of parameters the GUIs must set before calling the command
      # * :plugin (_Object_): The plugin that executes the command
      # map< Integer, map< Symbol, Object > >
      @Commands = {}
      @CommandPlugins.each do |iPluginName, iCommandPluginInfo|
        lCommandID = iCommandPluginInfo[:commandID]
        if (lCommandID == nil)
          logBug "Command plugin #{iPluginName} does not declare any command ID. Ignoring it. Please check the pluginInfo method from this plugin."
        else
          if (@Commands[lCommandID] == nil)
            @Commands[lCommandID] = {
              :title => iCommandPluginInfo[:title],
              :description => iCommandPluginInfo[:description],
              :bitmap => iCommandPluginInfo[:bitmap],
              :accelerator => iCommandPluginInfo[:accelerator],
              :parameters => iCommandPluginInfo[:parameters],
              :plugin => iCommandPluginInfo[:plugin]
            }
          else
            logBug "Command #{lCommandID} was already registered. There is a conflict in the commands. Please check command IDs returned by the pluginInfo methods of command plugins."
          end
        end
      end

      # Create commands for each import plugin
      @ImportPlugins.each do |iImportID, iImportInfo|
        @Commands[ID_IMPORT_BASE + iImportInfo[:index]] = {
          :title => "Import from #{iImportInfo[:title]}",
          :description => iImportInfo[:description],
          :bitmap => iImportInfo[:bitmap],
          :plugin => ImportCommand.new(iImportID, false),
          :accelerator => nil,
          :parameters => [
            :parentWindow
          ]
        }
        @Commands[ID_IMPORT_MERGE_BASE + iImportInfo[:index]] = {
          :title => "Import and merge from #{iImportInfo[:title]}",
          :description => iImportInfo[:description],
          :bitmap => iImportInfo[:bitmap],
          :plugin => ImportCommand.new(iImportID, true),
          :accelerator => nil,
          :parameters => [
            :parentWindow
          ]
        }
      end
      # Create commands for each export plugin
      @ExportPlugins.each do |iExportID, iExportInfo|
        @Commands[ID_EXPORT_BASE + iExportInfo[:index]] = {
          :title => "Export to #{iExportInfo[:title]}",
          :description => iExportInfo[:description],
          :bitmap => iExportInfo[:bitmap],
          :plugin => ExportCommand.new(iExportID),
          :accelerator => nil,
          :parameters => [
            :parentWindow
          ]
        }
      end
      # Create commands for each type plugin
      @TypesPlugins.each do |iTypeID, iTypeInfo|
        @Commands[ID_NEW_SHORTCUT_BASE + iTypeInfo[:index]] = {
          :title => iTypeInfo[:title],
          :description => "Create a new Shortcut of type #{iTypeInfo[:description]}",
          :bitmap => iTypeInfo[:bitmap],
          :plugin => NewShortcutCommand.new(iTypeID),
          :accelerator => nil,
          :parameters => [
            :tag,
            :parentWindow
          ]
        }
      end

      # Create Commands not yet implemented
      # TODO: Implement them
      @Commands.merge!({
        Wx::ID_FIND => {
          :title => 'Find',
          :description => 'Find a Shortcut',
          :bitmap => Wx::Bitmap.new("#{$PBS_GraphicsDir}/Find.png"),
          :accelerator => [ Wx::MOD_CMD, 'f'[0] ]
        },
        ID_STATS => {
          :title => 'Stats',
          :description => 'Give statistics on your Shortcuts use',
          :bitmap => Wx::Bitmap.new("#{$PBS_GraphicsDir}/Stats.png"),
          :accelerator => nil
        },
        Wx::ID_HELP => {
          :title => 'User manual',
          :description => 'Display help file',
          :bitmap => Wx::Bitmap.new("#{$PBS_GraphicsDir}/Help.png"),
          :accelerator => nil
        }
      })

      # Create dynamic parameters of commands
      @Commands.each do |iCommandID, ioCommandInfo|
        ioCommandInfo.merge!({
          :enabled => true,
          :registeredMenuItems => [],
          :registeredToolbarButtons => []
        })
      end

    end

    # First check if the dependencies of a given plugin file are satisfied, by requiring its libraries if needed.
    #
    # Parameters:
    # * *iPluginsMap* (<em>map<String,map<Symbol,Object>></em>): The map of plugins corresponding to this plugins type
    # * *iPluginsTypeID* (_String_): The type of plugins identifier
    # * *iPluginName* (_String_): The plugin name
    # * *oMissingDeps* (<em>map<String,[String,list<[String,String,map<String,map<Symbol,Object>>,list<Object>]>]></em>): The map of missing dependencies to fill
    # * *iParams* (<em>list<Object></em>): Additional parameters to give to the plugin constructor [optional]
    # Return:
    # * _Boolean_: Are there some missing dependencies ?
    def checkMissingDependencies(iPluginsMap, iPluginsTypeID, iPluginName, oMissingDeps, *iParams)
      rMissing = false

      if (File.exists?("#{$PBS_LibDir}/Plugins/#{iPluginsTypeID}/#{iPluginName}.dep.rb"))
        # Check dependencies
        lRequireDepsName = "Plugins/#{iPluginsTypeID}/#{iPluginName}.dep.rb"
        begin
          require lRequireDepsName
          begin
            lDeps = eval("#{iPluginsTypeID}::get#{iPluginName}Deps")
            lDeps.each do |iRequireName, iGemInstallCommand|
              # Test the require
              begin
                require iRequireName
              rescue Exception
                # Dependency missing
                if (oMissingDeps[iRequireName] == nil)
                  oMissingDeps[iRequireName] = [ iGemInstallCommand, [] ]
                elsif (oMissingDeps[iRequireName][0] != iGemInstallCommand)
                  logBug "Conflict of dependencies to install between 2 plugins. They both want to install #{iRequireName}. One wants '#{oMissingDeps[iRequireName][0]}', the other '#{iGemInstallCommand}'.\nPlease check .dep.rb files that declare dependencies.\nWill use '#{iGemInstallCommand}'."
                  oMissingDeps[iRequireName][0] = iGemInstallCommand
                end
                oMissingDeps[iRequireName][1] << [ iPluginsTypeID, iPluginName, iPluginsMap, iParams ]
                rMissing = true
              end
            end
          rescue Exception
            logBug "Error while instantiating one of the #{iPluginsTypeID} plugin dependencies (#{lRequireDepsName}): #{$!}\nCheck that class method PBS::#{iPluginsTypeID}::get#{iPluginName}Deps has been correctly defined in it.\nException stack:\n#{$!.backtrace.join("\n")}"
          end
        rescue Exception
          logBug "Error while instantiating one of the #{iPluginsTypeID} plugin dependencies (#{lRequireDepsName}): #{$!}\nException stack:\n#{$!.backtrace.join("\n")}"
        end
      end

      return rMissing
    end

    # Load a plugin.
    # Prerequisite: dependencies of this plugin have to be loadable
    #
    # Parameters:
    # * *ioPluginsMap* (<em>map<String,map<Symbol,Object>></em>): The map of plugins to fill
    # * *iPluginTypeID* (_String_): The plugin type ID
    # * *iPluginName* (_String_): The plugin name
    # * *iParams* (<em>list<Object></em>): Additional parameters to give to the plugin constructor [optional]
    def loadPlugin(ioPluginsMap, iPluginTypeID, iPluginName, *iParams)
      lRequireName = "Plugins/#{iPluginTypeID}/#{iPluginName}.rb"
      begin
        require lRequireName
        begin
          lPlugin = eval("#{iPluginTypeID}::#{iPluginName}.new(*iParams)")
          # Get the info of the plugin, and complete it
          lPluginInfo = {
            :title => iPluginName,
            :description => iPluginName,
            :bitmapName => 'Plugin.png',
          }
          if (lPlugin.class.method_defined?(:pluginInfo))
            lPluginInfo.merge!(lPlugin.pluginInfo)
          else
            logBug "Plugin #{iPluginName} does not have any pluginInfo method. Keeping default values."
          end
          # Create dynamic content of the plugin info
          lPluginInfo.merge!({
            :bitmap => Wx::Bitmap.new("#{$PBS_GraphicsDir}/#{lPluginInfo[:bitmapName]}"),
            :plugin => lPlugin,
            :index => ioPluginsMap.size
          })
          # Register the plugin
          ioPluginsMap[iPluginName] = lPluginInfo
          # Add the method pluginName to the object, as it can be useful later
          lPlugin.instance_eval("
def pluginName
  return '#{iPluginName}'
end
"
          )
        rescue Exception
          logBug "Error while instantiating one of the #{iPluginTypeID} plugin (#{lRequireName}): #{$!}\nCheck that class PBS::#{iPluginTypeID}::#{iPluginName} has been correctly defined in it.\nThis plugin will be ignored.\nException stack:\n#{$!.backtrace.join("\n")}"
        end
      rescue Exception
        logBug "Error while loading one of the #{iPluginTypeID} plugin (#{lRequireName}): #{$!}\nThis plugin will be ignored.\nException stack:\n#{$!.backtrace.join("\n")}"
      end
    end

    # Read the plugins identified by a given ID, and return a map of the instantiated plugins.
    #
    # Parameters:
    # * *ioPluginsMap* (<em>map<String,map<Symbol,Object>></em>): The map of plugins to fill
    # * *iPluginsID* (_String_): The plugins identifier
    # * *oMissingDeps* (<em>map<String,[String,list<[String,String,map<String,map<Symbol,Object>>,list<Object>]>]></em>): The map of missing dependencies to fill
    # * *iParams* (<em>list<Object></em>): Additional parameters to give to the plugin constructor [optional]
    def readPlugins(ioPluginsMap, iPluginsID, oMissingDeps, *iParams)
      Dir.glob("#{$PBS_LibDir}/Plugins/#{iPluginsID}/*.rb").each do |iFileName|
        lPluginName = File.basename(iFileName)[0..-4]
        # Ignore .dep.rb files
        # Check dependencies
        if ((File.extname(lPluginName) != '.dep') and
            (!checkMissingDependencies(ioPluginsMap, iPluginsID, lPluginName, oMissingDeps, *iParams)))
          loadPlugin(ioPluginsMap, iPluginsID, lPluginName, *iParams)
        end
      end
    end

    # Does a Tag equal another content ?
    #
    # Parameters:
    # * *iTag* (_Tag_): Existing Tag
    # * *iOtherName* (_String_): Name of other Tag
    # * *iOtherIcon* (<em>Wx::Bitmap</em>): Icon of other Tag
    # Return:
    # * _Boolean_: Does a Tag equal another content ?
    def tagSameAs?(iTag, iOtherName, iOtherIcon)
      rSame = false

      case @Options[:tagsUnicity]
      when TAGSUNICITY_NONE
        rSame = false
      when TAGSUNICITY_NAME
        rSame = (iTag.Name == iOtherName)
      when TAGSUNICITY_ALL
        if (iTag.Name == iOtherName)
          if ((iTag.Icon == nil) and
              (iOtherIcon == nil))
            rSame = true
          elsif ((iTag.Icon != nil) and
                 (iOtherIcon != nil))
            # Check the icon data only
            rSame = (iOtherIcon.convert_to_image.data == iTag.Icon.convert_to_image.data)
          end
        end
      else
        logBug "Unknown value for option :tagsUnicity: #{@Options[:tagsUnicity]}."
      end

      return rSame
    end

    # Does a Tag equal another serialized content ?
    # TODO (WxRuby): When Wx::Bitmap will be serializable, remove this method, and use tagSameAs? instead
    #
    # Parameters:
    # * *iTag* (_Tag_): Existing Tag
    # * *iOtherName* (_String_): Name of other Tag
    # * *iOtherIcon* (_String_): Serialized Icon of other Tag
    # Return:
    # * _Boolean_: Does a Tag equal another serialized content ?
    def tagSameAsSerialized?(iTag, iOtherName, iOtherIcon)
      lOtherIconBitmap = nil
      if (iOtherIcon != nil)
        lOtherIconBitmap = Wx::Bitmap.new
        lOtherIconBitmap.setSerialized(iOtherIcon)
      end

      return tagSameAs?(iTag, iOtherName, lOtherIconBitmap)
    end

    # Are 2 metadata equal ?
    #
    # Parameters:
    # * *iMetadata1* (<em>map<String,Object></em>): First metadata
    # * *iMetadata2* (<em>map<String,Object></em>): Second metadata
    # Return:
    # * _Boolean_: Are 2 metadata equal ?
    def metadataSameAs?(iMetadata1, iMetadata2)
      rSame = true

      # Check each property, as there is an exception for Wx::Bitmap, and also for missing properties equaling nil values.
      (iMetadata1.keys + iMetadata2.keys).sort.uniq.each do |iKey|
        lValue1 = iMetadata1[iKey]
        lValue2 = iMetadata2[iKey]
        if ((lValue1 != nil) or
            (lValue2 != nil))
          if (lValue1.is_a?(Wx::Bitmap))
            if (lValue2.is_a?(Wx::Bitmap))
              rSame = (lValue1.convert_to_image.data == lValue2.convert_to_image.data)
            else
              rSame = false
            end
          else
            rSame = (lValue1 == lValue2)
          end
        end
        if (rSame)
          # No need to continue
          break
        end
      end

      return rSame
    end

    # Does a Shortcut equal another content ?
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): Existing Shortcut
    # * *iOtherContent* (_Content_): Content of other Shortcut
    # * *iOtherMetadata* (<em>map<String,Object></em>): Metadata of other Shortcut
    # Return:
    # * _Boolean_: Does a Shortcut equal another content ?
    def shortcutSameAs?(iShortcut, iOtherContent, iOtherMetadata)
      rSame = false

      case @Options[:shortcutsUnicity]
      when SHORTCUTSUNICITY_NONE
        rSame = false
      when SHORTCUTSUNICITY_NAME
        rSame = (iShortcut.Metadata['title'] == iOtherMetadata['title'])
      when SHORTCUTSUNICITY_CONTENT
        rSame = (iShortcut.Content == iOtherContent)
      when SHORTCUTSUNICITY_METADATA
        rSame = metadataSameAs?(iShortcut.Metadata, iOtherMetadata)
      when SHORTCUTSUNICITY_ALL
        rSame = ((iShortcut.Content == iOtherContent) and
                 (metadataSameAs?(iShortcut.Metadata, iOtherMetadata)))
      else
        logBug "Unknown value for option :shortcutsUnicity: #{@Options[:shortcutsUnicity]}."
      end

      return rSame
    end

    # Does a Shortcut equal another serialized content ?
    # TODO (WxRuby): When Wx::Bitmap will be serializable, remove this method, and use shortcutSameAs? instead
    #
    # Parameters:
    # * *iShortcut* (_Shortcut_): Existing Shortcut
    # * *iOtherContent* (_Content_): Content of other Shortcut
    # * *iOtherMetadata* (<em>map<String,Object></em>): Serialized Metadata of other Shortcut
    # Return:
    # * _Boolean_: Does a Shortcut equal another serialized content ?
    def shortcutSameAsSerialized?(iShortcut, iOtherContent, iOtherMetadata)
      lMetadata = {}
      iOtherMetadata.each do |iKey, iValue|
        if ((iValue.is_a?(Array)) and
            (iValue.size == 2) and
            (iValue[0] == Wx::Bitmap))
          lBitmap = Wx::Bitmap.new
          lBitmap.setSerialized(iValue[1])
          lMetadata[iKey] = lBitmap
        else
          lMetadata[iKey] = iValue
        end
      end

      return shortcutSameAs?(iShortcut, iOtherContent, lMetadata)
    end

    # Ensure that we are in a current undoableOperation, and create a default one if not.
    #
    # Parameters:
    # * *iDefaultTitle* (_String_): Default title for the undoable operation
    def ensureUndoableOperation(iDefaultTitle)
      if (@CurrentUndoableOperation == nil)
        # Create a default undoable operation
        logBug "Operation \"#{iDefaultTitle}\" was not protected by undoableOperation, and it modifies some data. Create a default UndoableOperation."
        undoableOperation(iDefaultTitle) do
          yield
        end
      else
        yield
      end
    end

    # !!! Following methods have to be used ONLY by UAO_* classes.
    # !!! This is the only way to ensure that Undo/Redo management will behave correctly.

    # Set the current opened file name.
    # !!! This method has to be used only in the atomic operation replacing all the data
    #
    # Parameters:
    # * *iNewFileName* (_String_): New file name
    def _UNDO_setCurrentOpenedFileName(iNewFileName)
      @CurrentOpenedFileName = iNewFileName
    end

    # Set the current opened file modified flag
    # !!! This method has to be used only in the atomic operation replacing all the data
    #
    # Parameters:
    # * *iNewFileModified* (_Boolean_): The flag
    def _UNDO_setCurrentOpenedFileModified(iNewFileModified)
      @CurrentOpenedFileModified = iNewFileModified
    end

    # Add a new Shortcut
    # !!! This method has to be used only in the atomic operation adding new Shortcuts
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut to add
    def _UNDO_addShortcut(iSC)
      @ShortcutsList << iSC
    end

    # Delete a Shortcut
    # !!! This method has to be used only in the atomic operation adding new Shortcuts
    #
    # Parameters:
    # * *iSCToDelete* (_Shortcut_): The Shortcut to delete
    def _UNDO_deleteShortcut(iSCToDelete)
      @ShortcutsList.delete_if do |iSC|
        iSCToDelete == iSC
      end
    end

  end

end
