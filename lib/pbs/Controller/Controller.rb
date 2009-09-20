#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Controller/Actions'
require 'pbs/Controller/Notifiers'
require 'pbs/Controller/GUIHelpers'
require 'pbs/Controller/Readers'
require 'pbs/Controller/UndoableAtomicOperations'

module PBS

  # Define constants for commands that are not among predefined Wx ones
  # WxRuby takes 5000 - 6000 range.
  # TODO (WxRuby): Use an ID generator
  ID_OPEN_MERGE = 1000
  ID_NEW_TAG = 1001
  ID_STATS = 1002
  ID_DEVDEBUG = 1003
  ID_TIPS = 1004
  # Following constants are used in dialogs (for Buttons IDs and so return values)
  ID_MERGE_EXISTING = 2000
  ID_MERGE_CONFLICTING = 2001
  ID_KEEP = 2002
  # Following constants are base integers for plugins related commands.
  ID_IMPORT_BASE = 6000
  ID_IMPORT_MERGE_BASE = 7000
  ID_EXPORT_BASE = 8000
  ID_NEW_SHORTCUT_BASE = 9000
  ID_SHORTCUT_COMMAND_BASE = 10000
  ID_INTEGRATION_INSTANCE_BASE = 11000

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
        ioController.accessImportPlugin(@ImportPluginName) do |iPlugin|
          iPlugin.execute(ioController, iParams[:parentWindow])
        end
        if (@Merge)
          ioController.Merging = false
        end
      end

    end

    # Class used to factorize export commands
    class ExportCommand

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
        iController.accessExportPlugin(@ExportPluginName) do |iPlugin|
          iPlugin.execute(iController, iParams[:parentWindow])
        end
      end

    end

    # Class used to factorize new Shortcut commands
    class NewShortcutCommand

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
        ioController.accessTypesPlugin(@TypePluginName) do |iTypePlugin|
          lLocationName = ''
          if (lTag != nil)
            lLocationName = " in #{lTag.Name}"
          end
          require 'pbs/Windows/EditShortcutDialog'
          showModal(EditShortcutDialog, lWindow, nil, ioController.RootTag, ioController, iTypePlugin, lTag) do |iModalResult, iDialog|
            case iModalResult
            when Wx::ID_OK
              ioController.undoableOperation("Create new Shortcut#{lLocationName}") do
                lNewContent, lNewMetadata, lNewTags = iDialog.getData
                ioController.createShortcut(@TypePluginName, lNewContent, lNewMetadata, lNewTags)
              end
            end
          end
        end
      end

    end

    # Class used to factorize new Shortcut commands
    class ShortcutPluginCommand

      # Constructor
      #
      # Parameters:
      # * *iPluginName* (_String_): The plugin ID
      def initialize(iPluginName)
        @PluginName = iPluginName
      end

      # Command that creates a new Shortcut via the corresponding Type plugin
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *shortcutsList* (<em>list<Shortcut></em>): List of Shortcuts for which this command was called
      def execute(ioController, iParams)
        lShortcutsList = iParams[:shortcutsList]
        ioController.accessShortcutCommandsPlugin(@PluginName) do |iPlugin|
          ioController.undoableOperation("#{iPlugin.pluginDescription[:Title]} on #{lShortcutsList.size} Shortcuts") do
            lShortcutsList.each do |ioShortcut|
              # Call the plugin
              iPlugin.execute(ioController, ioShortcut)
            end
          end
        end
      end

    end

    # Class used to instantiate a default integration plugin
    class InstantiateDefaultIntCommand

      # Constructor
      #
      # Parameters:
      # * *iPluginName* (_String_): The plugin ID
      def initialize(iPluginName)
        @PluginName = iPluginName
      end

      # Command that creates a new Shortcut via the corresponding Type plugin
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      def execute(ioController)
        # First check if this plugin already has a declared instance for the Root Tag
        lOldOptions = ioController.Options.clone
        lFound = false
        lRootTagID = ioController.getTagID(ioController.RootTag)
        if (ioController.Options[:intPluginsOptions][@PluginName] != nil)
          lIdx = 0
          ioController.Options[:intPluginsOptions][@PluginName].each do |ioInstancePluginInfo|
            iTagID, iActive, iOptions, iInstancesInfo = ioInstancePluginInfo
            if (iTagID == lRootTagID)
              # Found it
              lFound = true
              if (iActive)
                logMsg "There is already an active view #{@PluginName}."
                lOldOptions = nil
              else
                # Make sure the list we will modify is cloned
                lOldOptions[:intPluginsOptions][@PluginName][lIdx] = ioInstancePluginInfo.clone
                ioController.Options[:intPluginsOptions][@PluginName][lIdx][1] = true
              end
              break
            end
            lIdx += 1
          end
        end
        if (!lFound)
          if (ioController.Options[:intPluginsOptions][@PluginName] == nil)
            ioController.Options[:intPluginsOptions][@PluginName] = []
          end
          # Make sure the list we will modify is cloned
          lOldOptions[:intPluginsOptions][@PluginName] = ioController.Options[:intPluginsOptions][@PluginName].clone
          # Create a new one
          ioController.accessIntegrationPlugin(@PluginName) do |iPlugin|
            ioController.Options[:intPluginsOptions][@PluginName] << [
              lRootTagID,
              true,
              iPlugin.getDefaultOptions,
              [ nil, nil ]
            ]
          end
        end
        if (lOldOptions != nil)
          ioController.notifyOptionsChanged(lOldOptions)
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

      # Title of the Undoable operation
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

    # Class used to receive notifications about Tags modifications that might alter Options
    class OptionsListener

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The controller
      def initialize(iController)
        @Controller = iController
      end

      # Notify that a given Tag's children list has changed
      #
      # Parameters:
      # * *iParentTag* (_Tag_): The Tag whose children list has changed
      # * *iOldChildrenList* (<em>list<Tag></em>): The old children list
      def onTagChildrenUpdate(iParentTag, iOldChildrenList)
        # List of impacted Tag names
        # list< String >
        lImpactedTagNames = []
        # First check removed Tag names
        iOldChildrenList.each do |iOldSubTag|
          if (!iParentTag.Children.include?(iOldSubTag))
            # iOldSubTag was deleted
            lImpactedTagNames << iOldSubTag.Name
          end
        end
        # The check added Tags
        iParentTag.Children.each do |iNewSubTag|
          if (!iOldChildrenList.include?(iNewSubTag))
            # iNewSubTag was added
            lImpactedTagNames << iNewSubTag.Name
          end
        end
        # Now, every integration plugin that is instantiated for a Tag which has at least 1 of the impacted Tags' name among its ID should be checked.
        @Controller.checkIntPluginsTags(lImpactedTagNames)
      end

      # An update has occured on a Tag's data
      #
      # Parameters:
      # * *iTag* (_Tag_): The Tag whose data was invalidated
      # * *iOldName* (_String_): The previous name
      # * *iOldIcon* (<em>Wx::Bitmap</em>): The previous icon (can be nil)
      def onTagDataUpdate(iTag, iOldName, iOldIcon)
        # List of impacted Tag names
        # list< String >
        lImpactedTagNames = []
        # We update the tree accordingly
        if (iTag.Name != iOldName)
          # iTag has been renamed
          lImpactedTagNames << iOldName
          lImpactedTagNames << iTag.Name
        end
        # Now, every integration plugin that is instantiated for a Tag which has at least 1 of the impacted Tags' name among its ID should be checked.
        @Controller.checkIntPluginsTags(lImpactedTagNames)
      end

    end

    # Do we merge the next command launched ?
    #   Boolean
    attr_accessor :Merging

    # Give access to a plugin.
    # Handle exceptions with logErr, logBug and logExc
    #
    # Parameters:
    # * *iCategoryName* (_String_): Category of the plugin to access
    # * *iPluginName* (_String_): Name of the plugin to access
    # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
    # ** *OnlyIfExtDepsResolved* (_Boolean_): Do we return the plugin only if there is no need to install external dependencies ? [optional = false]
    # ** *RDIInstaller* (<em>RDI::Installer</em>): The RDI installer if available, or nil otherwise [optional = nil]
    # * *CodeBlock*: The code called when the plugin is found:
    # ** *ioPlugin* (_Object_): The corresponding plugin
    def accessPlugin_Protected(iCategoryName, iPluginName)
      begin
        lContextModifiers = {}
        accessPlugin(iCategoryName, iPluginName,
          :RDIContextModifiers => lContextModifiers
        ) do |ioPlugin|
          yield(ioPlugin)
        end
        # Add the eventual context modifiers to the current ones
        if (!lContextModifiers.empty?)
          logDebug "Add context modifiers applied: #{lContextModifiers.inspect}"
          lContextModifiers.each do |iDepID, iCMList|
            if (@Options[:RDIContextModifiers][RUBY_PLATFORM][iDepID] == nil)
              @Options[:RDIContextModifiers][RUBY_PLATFORM][iDepID] = []
            end
            @Options[:RDIContextModifiers][RUBY_PLATFORM][iDepID] << iCMList
          end
        end
      rescue PluginDependenciesIgnoredError
        # That was cancelled on purpose by the user (ignoring dependencies)
        logErr $!
      rescue PluginDependenciesUnresolvedError
        # The user is aware if those unresolved dependencies
        logErr $!
      rescue Exception
        # This is not normal
        logExc $!, "Error while loading plugin #{iPluginName} from category #{iCategoryName}: #{$!}"
      end
    end

    # Update the instantiated plugins instance
    #
    # Parameters:
    # * *iPluginID* (_String_): The integration plugin ID
    # * *ioInstantiatedPluginInfo* (<em>[list<String>,Boolean,Object,[Object,Tag]]</em>): The instantiated plugin info
    # * *iOldOptions* (_Object_): Old options (used for notifications only)
    # * *iOldTagID* (<em>list<String></em>): Old Tag ID (used for notifications only)
    # * *iNotifyChanges* (_Boolean_): Do we notify the user about changes in plugin instances ? [optional = false]
    def updateIntPluginsInstance(iPluginID, ioInstantiatedPluginInfo, iOldOptions, iOldTagID, iNotifyChanges = false)
      iTagID, iActive, iOptions, ioInstanceInfo = ioInstantiatedPluginInfo
      ioInstance, iTag = ioInstanceInfo
      # We notify or take actions in creating/deleting instances if there are changes
      if (iActive)
        if (ioInstance == nil)
          # We have to create the instance
          lTag = iTag
          if (lTag == nil)
            # First check if the TagID points to a correct Tag
            lTags = getTagsFromTagID(iTagID, @RootTag)
            if (lTags.empty?)
              # No Tag corresponds to this TagID
              logErr "Unable to get a Tag corresponding to ID #{iTagID.join('/')}: instance of integration plugin #{getIntegrationPlugins[iPluginID][:Title]} will be ignored."
            else
              if (lTags.size > 1)
                # Several Tags correspond
                logErr "Several Tags correspond to ID #{iTagID.join('/')}: instance of integration plugin #{getIntegrationPlugins[iPluginID][:Title]} will be instantiated for an arbitrary one.\nPlease name your Tags differently if you want to remove the ambiguity."
              end
              lTag = lTags[0]
              ioInstanceInfo[1] = lTag
            end
          end
          if (lTag == nil)
            # We can't create it for now. We need to have the correct existing Tag. Disable it for now to avoid further errors each time we change options.
            ioInstantiatedPluginInfo[1] = false
          else
            logDebug "Instantiate integration plugin #{iPluginID} for Tag #{lTag.Name}"
            begin
              accessIntegrationPlugin(iPluginID) do |iPlugin|
                ioInstanceInfo[0] = iPlugin.createNewInstance(self)
                # And notify its options
                ioInstanceInfo[0].onPluginOptionsChanged(iOptions, lTag, iOldOptions, iOldTagID)
                if (iNotifyChanges)
                  logMsg "Plugin #{iPlugin.pluginDescription[:Title]} has been instantiated for Tag #{lTag.Name}"
                end
                # Register it
                registerGUI(ioInstanceInfo[0])
              end
            rescue Exception
              logExc $!, "Exception while instantiating plugin instance #{iPluginID} for Tag #{iTagID.join('/')}"
            end
          end
        else
          if (iOldTagID != iTagID)
            # It has changed: notify it
            lTag = nil
            # We need to find the new Tag corresponding to this new TagID
            lTags = getTagsFromTagID(iTagID, @RootTag)
            if (lTags.empty?)
              # No Tag corresponds to this TagID
              logErr "Unable to get a Tag corresponding to ID #{iTagID.join('/')}: instance of integration plugin #{getIntegrationPlugins[iPluginID][:Title]} will be ignored."
            else
              if (lTags.size > 1)
                # Several Tags correspond
                logErr "Several Tags correspond to ID #{iTagID.join('/')}: instance of integration plugin #{getIntegrationPlugins[iPluginID][:Title]} will be instantiated for an arbitrary one.\nPlease name your Tags differently if you want to remove the ambiguity."
              end
              lTag = lTags[0]
              ioInstanceInfo[1] = lTag
            end
            if (lTag == nil)
              # We have to remove the instance, as its Tag can't be found
              logDebug "Delete integration plugin #{iPluginID} for Tag #{iTagID.join('/')}"
              # Unregister the GUI
              unregisterGUI(ioInstanceInfo[0])
              begin
                accessIntegrationPlugin(iPluginID) do |iPlugin|
                  iPlugin.deleteInstance(self, ioInstance)
                end
              rescue Exception
                logExc $!, "Exception while deleting plugin instance #{iPluginID} for Tag #{iTagID.join('/')}"
              end
              # Delete from the internals
              ioInstanceInfo[0] = nil
              # Also reset the Tag, as we will want to recompute it when instantiating
              ioInstanceInfo[1] = nil
            else
              # Notify options changed
              logDebug "Notify changing options for integration plugin #{iPluginID} for Tag #{lTag.Name}"
              begin
                ioInstance.onPluginOptionsChanged(iOptions, lTag, iOldOptions, iOldTagID)
              rescue Exception
                logExc $!, "Exception while notifying plugin instance #{iPluginID} for Tag #{iTagID.join('/')}"
              end
            end
          elsif (iOldOptions != iOptions)
            # It has changed: notify it
            logDebug "Notify changing options for integration plugin #{iPluginID} for Tag #{iTagID.join('/')}"
            begin
              ioInstance.onPluginOptionsChanged(iOptions, iTag, iOldOptions, iOldTagID)
            rescue Exception
              logExc $!, "Exception while notifying plugin instance #{iPluginID} for Tag #{iTagID.join('/')}"
            end
          end
        end
      else
        if (ioInstance != nil)
          # We have to delete the instance
          logDebug "Delete integration plugin #{iPluginID} for Tag #{iTagID.join('/')}"
          # Unregister the GUI
          unregisterGUI(ioInstanceInfo[0])
          begin
            accessIntegrationPlugin(iPluginID) do |iPlugin|
              iPlugin.deleteInstance(self, ioInstance)
            end
          rescue Exception
            logExc $!, "Exception while deleting plugin instance #{iPluginID} for Tag #{iTagID.join('/')}"
          end
          # Delete from the internals
          ioInstanceInfo[0] = nil
          # Also reset the Tag, as we will want to recompute it when instantiating
          ioInstanceInfo[1] = nil
        end
      end
    end

    # Check integration plugins instantiated for some specific Tags after some changes in the Tags
    #
    # Parameters:
    # * *iTagNames* (<em>list<String></em>): List of Tag names that may be impacted
    def checkIntPluginsTags(iTagNames)
      if (!iTagNames.empty?)
        # For each plugin, check if there is a name part of iTagNames
        @Options[:intPluginsOptions].each do |iPluginID, ioPluginsList|
          ioPluginsList.each do |ioInstantiatedPluginInfo|
            iTagID, iActive, iOptions, ioInstanceInfo = ioInstantiatedPluginInfo
            # Check if iTagID might be impacted
            iTagNames.each do |iTagName|
              if (iTagID.include?(iTagName))
                # Yes, it can be impacted
                updateIntPluginsInstance(iPluginID, ioInstantiatedPluginInfo, nil, nil, true)
                break
              end
            end
          end
        end
      end
    end

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
              require 'pbs/Windows/ResolveTagConflictDialog'
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
              logErr "Tags conflict between #{ioChildTag.Name} and #{iTagName}."
              rAction = Wx::ID_CANCEL
            elsif (@Options[:tagsConflict] == TAGSCONFLICT_CANCEL_ALL)
              logErr "Tags conflict between #{ioChildTag.Name} and #{iTagName}."
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
              require 'pbs/Windows/ResolveShortcutConflictDialog'
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
              logErr << "Shortcuts conflict between #{ioSC.Metadata['title']} and #{iMetadata['title']}."
              rAction = Wx::ID_CANCEL
            elsif (@Options[:shortcutsConflict] == SHORTCUTSCONFLICT_CANCEL_ALL)
              logErr << "Shortcuts conflict between #{ioSC.Metadata['title']} and #{iMetadata['title']}."
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
            logExc $!, 'A notified GUI (maybe from an Integration Plugin) threw an exception'
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

    # Unregister a GUI that was notified upon events
    #
    # Parameters:
    # * *iGUI* (_Object_): The GUI to be notified.
    def unregisterGUI(iGUI)
      lFound = false
      @RegisteredGUIs.delete_if do |iExistingGUI|
        lFound = true
        next (iExistingGUI == iGUI)
      end
      if (!lFound)
        logBug "Gui #{iGUI} should have been registered to handle events, but we can't retrieve it."
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
      lTitle = lCommand[:Title]
      if (iParams[:GUITitle] != nil)
        lTitle = iParams[:GUITitle]
      end
      if (lCommand[:Accelerator] != nil)
        lTitle += "\t#{getStringForAccelerator(lCommand[:Accelerator])}"
      end
      ioMenuItem.text = lTitle
      ioMenuItem.help = lCommand[:Description]
      ioMenuItem.bitmap = lCommand[:Bitmap]
      # Insert it
      oMenu.insert(iMenuItemPos, ioMenuItem)
      lEnabled = ((lCommand[:Enabled]) and
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
      iCommand[:RegisteredMenuItems].delete_if do |iMenuItemInfo|
        iMenuItem, iEvtWindow, iParametersCode, iAdditionalParams = iMenuItemInfo
        ioMenuItem == iMenuItem
      end
      # Create the new one and register it
      lNewMenuItem = Wx::MenuItem.new(lMenu, lCommandID)
      iCommand[:RegisteredMenuItems] << [ lNewMenuItem, iEvtWindow, iFetchParametersCode, iParams ]
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
        lCommand[:RegisteredMenuItems].each do |iMenuItemInfo|
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
      lTitle = iCommand[:Title]
      if (iParams[:GUITitle] != nil)
        lTitle = iParams[:GUITitle]
      end
      if (iCommand[:Accelerator] != nil)
        lTitle += " (#{getStringForAccelerator(iCommand[:Accelerator])})"
      end
      lToolbar.set_tool_normal_bitmap(lCommandID, iCommand[:Bitmap])
      lToolbar.set_tool_short_help(lCommandID, lTitle)
      lToolbar.set_tool_long_help(lCommandID, iCommand[:Description])
      lEnabled = ((iCommand[:Enabled]) and
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
        lCommand[:RegisteredToolbarButtons].each do |iToolbarButtonInfo|
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
      lCommandParams[:RegisteredMenuItems].each do |ioMenuItemInfo|
        ioMenuItem, iEvtWindow, iParametersCode, iAdditionalParams = ioMenuItemInfo
        updateMenuItemAppearance(ioMenuItem, lCommandParams, iEvtWindow, iParametersCode, iAdditionalParams)
      end
      lCommandParams[:RegisteredToolbarButtons].each do |ioToolbarButtonInfo|
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
    #
    # Parameters:
    # * *iPBSRootDir* (_String_): PBS Root dir
    def initialize(iPBSRootDir)
      @PBSRootDir = iPBSRootDir
      
      # Name of the default options file
      @DefaultOptionsFile = "#{iPBSRootDir}/Options.pbso"
      # Name of the tips file
      @TipsFile = "#{iPBSRootDir}/tips.txt"

      # Opened file context
      @CurrentOpenedFileName = nil
      @CurrentOpenedFileModified = false
      @Merging = false

      # Do we load the default options ?
      lDefaultOptionsLoaded = false

      # The tips provider
      @TipsProvider = nil

      # Undo/Redo management
      # Controller::UndoableOperation
      @CurrentUndoableOperation = nil
      # list< Controller::UndoableOperation >
      @UndoStack = []
      # list< Controller::UndoableOperation >
      @RedoStack = []
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
        # The list of possible context modifiers to try, per platform and per dependency ID
        # map< String, map< String, list< list< [ String, Object ] > > > >
        # map< PlatformID, map< DepID, list< list< [ ContextModifierName, Location ] > > > >
        :RDIContextModifiers => {},
        # The options linked to each instance of Integration plugins:
        # For each Plugin ID, there is a list of [ Tag ID to represent in this plugin, Is it active ?, Options, [ Instantiated plugin, Tag ] ]
        # The instantiated plugin and Tag objects are in a separate list as it is needed to have a single object for cloned options (this object will be used to retrieve correspondances between old and new options).
        # map< String, list< [ TagID, Boolean, Object, [ Object, Tag ] ] > >
        # map< PluginName, list< [ TagID, Enabled?, Options, [ Instance, Tag ] ] > >
        :intPluginsOptions => {},
        # Last tip index shown
        # Integer
        :lastIdxTip => 0,
        # Do we display tips at startup ?
        :displayStartupTips => true
      }
      if (File.exists?(@DefaultOptionsFile))
        # Load options from the file
        @Options.merge!(openOptionsData(@DefaultOptionsFile))
      else
        lDefaultOptionsLoaded = true
      end

      # Set the context modifiers to try
      if (@Options[:RDIContextModifiers][RUBY_PLATFORM] == nil)
        @Options[:RDIContextModifiers][RUBY_PLATFORM] = {}
      end
      RDI::Installer.getMainInstance.setDefaultOptions(
        :PossibleContextModifiers => @Options[:RDIContextModifiers][RUBY_PLATFORM]
      )
      
      # The GUIS registered
      # list< Object >
      @RegisteredGUIs = []

      # Read plugins
      parsePluginsFromDir('Type', "#{iPBSRootDir}/lib/pbs/Plugins/Types", 'PBS::Types')
      parsePluginsFromDir('Import', "#{iPBSRootDir}/lib/pbs/Plugins/Imports", 'PBS::Imports')
      parsePluginsFromDir('Export', "#{iPBSRootDir}/lib/pbs/Plugins/Exports", 'PBS::Exports')
      parsePluginsFromDir('Integration', "#{iPBSRootDir}/lib/pbs/Plugins/Integration", 'PBS::Integration')
      parsePluginsFromDir('Command', "#{iPBSRootDir}/lib/pbs/Plugins/Commands", 'PBS::Commands')
      parsePluginsFromDir('ShortcutCommand', "#{iPBSRootDir}/lib/pbs/Plugins/ShortcutCommands", 'PBS::ShortcutCommands')

      # Complete the descriptions for each plugin
      [ 'Type', 'Import', 'Export', 'Integration', 'Command', 'ShortcutCommand' ].each do |iCategoryName|
        getPluginNames(iCategoryName).each do |iPluginName|
          lDesc = getPluginDescription(iCategoryName, iPluginName)
          if (lDesc[:Title] == nil)
            lDesc[:Title] = iPluginName
          end
          if (lDesc[:Description] == nil)
            lDesc[:Description] = iPluginName
          end
          if (lDesc[:BitmapName] == nil)
            lDesc[:BitmapName] = 'Plugin.png'
          end
        end
      end

      # Create the base of the data model:
      # * The root Tag
      #   Tag
      @RootTag = Tag.new('Root', nil)
      # * The Shortcuts list
      #   list< Shortcut >
      @ShortcutsList = []

      # Create the commands info
      # This variable maps each command ID with its info, including:
      # * :Title (_String_): The title
      # * :Description (_String_): The description
      # * :Bitmap (<em>Wx::Bitmap</em>): The bitmap
      # * :Accelerator (<em>[Integer,Integer]</em>): The accelerator key (Modifier and Key)
      # * :Parameters (<em>list<Symbol></em>): The list of parameters the GUIs must set before calling the command
      # * :PluginName (_String_): Name of the Command plugin that instantiates this command
      # * :Plugin (_Object_): The plugin that executes the command
      # map< Integer, map< Symbol, Object > >
      @Commands = {}
      getCommandPlugins.each do |iPluginName, iCommandPluginInfo|
        lCommandID = iCommandPluginInfo[:CommandID]
        if (lCommandID == nil)
          logBug "Command plugin #{iPluginName} does not declare any command ID. Ignoring it. Please check the pluginInfo method from this plugin."
        else
          if (@Commands[lCommandID] == nil)
            @Commands[lCommandID] = {
              :Title => iCommandPluginInfo[:Title],
              :Description => iCommandPluginInfo[:Description],
              :Bitmap => getPluginBitmap(iCommandPluginInfo),
              :Accelerator => iCommandPluginInfo[:Accelerator],
              :Parameters => iCommandPluginInfo[:Parameters],
              :Plugin => nil,
              :PluginName => iPluginName
            }
          else
            logBug "Command #{lCommandID} was already registered. There is a conflict in the commands. Please check command IDs returned by the pluginInfo methods of command plugins."
          end
        end
      end

      # Create commands for each import plugin
      getImportPlugins.each do |iImportID, iImportInfo|
        @Commands[ID_IMPORT_BASE + iImportInfo[:PluginIndex]] = {
          :Title => "Import from #{iImportInfo[:Title]}",
          :Description => iImportInfo[:Description],
          :Bitmap => getPluginBitmap(iImportInfo),
          :Plugin => ImportCommand.new(iImportID, false),
          :Accelerator => nil,
          :Parameters => [
            :parentWindow
          ]
        }
        @Commands[ID_IMPORT_MERGE_BASE + iImportInfo[:PluginIndex]] = {
          :Title => "Import and merge from #{iImportInfo[:Title]}",
          :Description => iImportInfo[:Description],
          :Bitmap => getPluginBitmap(iImportInfo),
          :Plugin => ImportCommand.new(iImportID, true),
          :Accelerator => nil,
          :Parameters => [
            :parentWindow
          ]
        }
      end
      # Create commands for each export plugin
      getExportPlugins.each do |iExportID, iExportInfo|
        @Commands[ID_EXPORT_BASE + iExportInfo[:PluginIndex]] = {
          :Title => "Export to #{iExportInfo[:Title]}",
          :Description => iExportInfo[:Description],
          :Bitmap => getPluginBitmap(iExportInfo),
          :Plugin => ExportCommand.new(iExportID),
          :Accelerator => nil,
          :Parameters => [
            :parentWindow
          ]
        }
      end
      # Create commands for each type plugin
      getTypesPlugins.each do |iTypeID, iTypeInfo|
        @Commands[ID_NEW_SHORTCUT_BASE + iTypeInfo[:PluginIndex]] = {
          :Title => iTypeInfo[:Title],
          :Description => "Create a new Shortcut of type #{iTypeInfo[:Description]}",
          :Bitmap => getPluginBitmap(iTypeInfo),
          :Plugin => NewShortcutCommand.new(iTypeID),
          :Accelerator => nil,
          :Parameters => [
            :tag,
            :parentWindow
          ]
        }
      end
      # Create commands for each Shortcut command plugin
      getShortcutCommandsPlugins.each do |iPluginID, iPluginInfo|
        @Commands[ID_SHORTCUT_COMMAND_BASE + iPluginInfo[:PluginIndex]] = {
          :Title => iPluginInfo[:Title],
          :Description => iPluginInfo[:Description],
          :Bitmap => getPluginBitmap(iPluginInfo),
          :Plugin => ShortcutPluginCommand.new(iPluginID),
          :Accelerator => iPluginInfo[:Accelerator],
          :Parameters => [
            :shortcutsList
          ]
        }
      end
      # Create commands that instantiate an instance on the Root Tag for each integration plugin
      getIntegrationPlugins.each do |iPluginID, iPluginInfo|
        @Commands[ID_INTEGRATION_INSTANCE_BASE + iPluginInfo[:PluginIndex]] = {
          :Title => iPluginInfo[:Title],
          :Description => iPluginInfo[:Description],
          :Bitmap => getPluginBitmap(iPluginInfo),
          :Plugin => InstantiateDefaultIntCommand.new(iPluginID),
          :Accelerator => iPluginInfo[:Accelerator]
        }
      end

      # Create Commands not yet implemented
      # TODO: Implement them
      @Commands.merge!({
        Wx::ID_FIND => {
          :Title => 'Find',
          :Description => 'Find a Shortcut',
          :Bitmap => getGraphic('Find.png'),
          :Accelerator => [ Wx::MOD_CMD, 'f'[0] ]
        },
        ID_STATS => {
          :Title => 'Stats',
          :Description => 'Give statistics on your Shortcuts use',
          :Bitmap => getGraphic('Stats.png'),
          :Accelerator => nil
        },
        Wx::ID_HELP => {
          :Title => 'User manual',
          :Description => 'Display help file',
          :Bitmap => getGraphic('Help.png'),
          :Accelerator => nil
        }
      })

      # Create dynamic parameters of commands
      @Commands.each do |iCommandID, ioCommandInfo|
        ioCommandInfo.merge!({
          :Enabled => true,
          :RegisteredMenuItems => [],
          :RegisteredToolbarButtons => []
        })
      end

      if (lDefaultOptionsLoaded)
        # Now we mark 1 instance per integration plugin to be instantiated on the Root Tag.
        getIntegrationPlugins.each do |iPluginID, iPluginInfo|
          accessIntegrationPlugin(iPluginID) do |iPlugin|
            @Options[:intPluginsOptions][iPluginID] = [
              [ [], true, iPlugin.getDefaultOptions, [ nil, nil ] ]
            ]
          end
        end
      end

      # Handle tips
      # Count number of tips
      lNbrTips = 0
      if (File.exists?(@TipsFile))
        File.open(@TipsFile, 'r') do |iFile|
          lNbrTips = iFile.readlines.size
        end
        if (@Options[:lastIdxTip] >= lNbrTips)
          @Options[:lastIdxTip] = 0
        end
        @TipsProvider = Wx::create_file_tip_provider(@TipsFile, @Options[:lastIdxTip])
      else
        logBug "Missing Tips file: #{@TipsFile}."
      end

    end

    # Is there at least 1 active integration plugin ?
    #
    # Return:
    # * _Boolean_: Is there at least 1 active integration plugin ?
    def isIntPluginActive?
      rActiveOK = false

      @Options[:intPluginsOptions].each do |iPluginID, iPluginsListInfo|
        iPluginsListInfo.each do |iPluginInfo|
          iTagID, iActive, iOptions, iInstanceInfo = iPluginInfo
          if (iActive)
            rActiveOK = true
            break
          end
        end
        if (rActiveOK)
          break
        end
      end

      return rActiveOK
    end
    
    # Show tips
    #
    # Parameters:
    # * *iParentWindow* (<em>Wx::Window</em>): The parent window
    def showTips(iParentWindow)
      if (@TipsProvider != nil)
        @Options[:displayStartupTips] = Wx::show_tip(iParentWindow, @TipsProvider)
      else
        logBug 'Tips could not be loaded correctly.'
      end
    end

    # Get the Tags associated to a given TagID, starting from a given Tag
    #
    # Parameters:
    # * *iTagID* (<em>list<String></em>): The Tag ID
    # * *iTag* (_Tag_): The Tag to start the search from
    # Return:
    # * <em>list<Tag></em>: The retrieved Tags
    def getTagsFromTagID(iTagID, iTag)
      rFoundTags = []

      if (iTagID.empty?)
        rFoundTags << iTag
      else
        lFirstChildName = iTagID[0]
        # Check if there is a child of iTag of this name
        iTag.Children.each do |iSubTag|
          if (iSubTag.Name == lFirstChildName)
            # Found it
            rFoundTags += getTagsFromTagID(iTagID[1..-1], iSubTag)
          end
        end
      end

      return  rFoundTags
    end

    # Get a Tag ID of a given Tag
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag
    # Return:
    # * <em>list<String></em>: The Tag ID
    def getTagID(iTag)
      rID = []

      lCurrentTag = iTag
      while (lCurrentTag != @RootTag)
        rID.insert(0, lCurrentTag.Name)
        lCurrentTag = lCurrentTag.Parent
      end

      return rID
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
        if (!rSame)
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
      return shortcutSameAs?(iShortcut, iOtherContent, getFromMarshallableObject(iOtherMetadata))
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
