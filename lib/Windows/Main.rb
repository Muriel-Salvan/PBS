#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Tools.rb'

module PBS

  # Main application frame
  class MainFrame < Wx::Frame

    include Tools

    # Set one of tree's node attributes to fit its associated data (Tag or Shortcut).
    # Only this method knows how to display tree nodes.
    #
    # Parameters:
    # * *iItemID* (_Integer_): The item of the main tree that we want to update
    def updateMainTreeNode(iItemID)
      lID, lObject = @TCMainTree.get_item_data(iItemID)
      case lID
      when ID_TAG
        @TCMainTree.set_item_text(iItemID, lObject.Name)
      when ID_SHORTCUT
        lTitle = lObject.Metadata['title']
        if (lTitle == nil)
          lTitle = '-- Unknown title --'
        end
        @TCMainTree.set_item_text(iItemID, lTitle)
      else
        puts "!!! Tree node #{iItemID} has unknown ID (#{lID}). It will be marked in the tree. Bug ?"
        @TCMainTree.set_item_text(iItemID, "!!! Unknown Data ID (Node ID: #{iItemID}, Data ID: #{lID}) !!!")
      end
    end

    # Remove a branch of the main tree
    #
    # Parameters:
    # * *iNodeID* (_Integer_): The node ID, root of the branch to remove
    def removeTreeBranch(iNodeID)
      # First remove children branches
      @TCMainTree.children(iNodeID).each do |iChildID|
        removeTreeBranch(iChildID)
      end
      # Then remove the root registered info
      lID, lObject = @TCMainTree.get_item_data(iNodeID)
      case lID
      when ID_TAG
        # Remove a Tag reference
        @TagsToMainTree.delete(lObject)
      when ID_SHORTCUT
        # Remove a Shortcut reference
        # Nothing to do
      else
        puts "!!! We are trying to remove a tree node (ID = #{iNodeID}) that is not registered as a Tag not a Shortcut (ID = #{lID}). Bug ?"
      end
      # And remove the node itself
      @TCMainTree.delete(iNodeID)
    end

    # Insert a Tag in the main tree, and recursively all its children Tags and associated Shortcuts
    #
    # Parameters:
    # * *iParentID* (_Integer_): The node ID where the Tag will be inserted
    # * *iTag* (_Tag_): The Tag to insert
    def insertTreeBranch(iParentID, iTag)
      # Insert the new node
      lTagNodeID = @TCMainTree.append_item(iParentID, '')
      @TCMainTree.set_item_data(lTagNodeID, [ID_TAG, iTag])
      @TagsToMainTree[iTag] = lTagNodeID
      updateMainTreeNode(lTagNodeID)
      # Insert its children Tags also
      iTag.Children.each do |iChildTag|
        insertTreeBranch(lTagNodeID, iChildTag)
      end
      # Insert its associated Shortcuts
      @Controller.ShortcutsList.each do |iSC|
        if (iSC.Tags.has_key?(iTag))
          # Insert iSC as a child
          lSCNodeID = @TCMainTree.append_item(lTagNodeID, '')
          @TCMainTree.set_item_data(lSCNodeID, [ID_SHORTCUT, iSC])
          updateMainTreeNode(lSCNodeID)
        end
      end
    end

    # Add information about a Shortcut into the main tree
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut to add
    def addShortcutInfoToMainTree(iSC)
      if (iSC.Tags.empty?)
        # Put at the root
        lNewNodeID = @TCMainTree.append_item(@RootID, '')
        @TCMainTree.set_item_data(lNewNodeID, [ID_SHORTCUT, iSC])
        updateMainTreeNode(lNewNodeID)
      else
        iSC.Tags.each do |iTag, iNil|
          lTagID = @TagsToMainTree[iTag]
          if (lTagID == nil)
            puts "!!! Shortcut #{iSC.Metadata['title']} is tagged with #{iTag.Name}, which does not exist in the known tags."
          else
            lNewNodeID = @TCMainTree.append_item(lTagID, '')
            @TCMainTree.set_item_data(lNewNodeID, [ID_SHORTCUT, iSC])
            updateMainTreeNode(lNewNodeID)
          end
        end
      end
    end

    # Securely update the main tree.
    # This method freezes the tree and ensures it becomes unfrozen.
    #
    # Parameters:
    # * *CodeBlock*: Code to execute while the tree is frozen
    def updateMainTree
      # First, freeze it for better performance during update
      @TCMainTree.freeze
      yield
      # Unfreeze it
      @TCMainTree.thaw
      # Redraw it
      @TCMainTree.refresh
    end

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

    # Delete an object (found in item_data) that is a direct child of a given Node ID
    #
    # Parameters:
    # * *iParentNodeID* (_Integer_): The parent node ID
    # * *iObject* (_Object_): The object to find
    def deleteObjectFromTree(iParentNodeID, iObject)
      # Find the node to delete
      lFound = false
      @TCMainTree.children(iParentNodeID).each do |iChildNodeID|
        lID, lObject = @TCMainTree.get_item_data(iChildNodeID)
        if (lObject == iObject)
          # Found it
          @TCMainTree.delete(iChildNodeID)
          lFound = true
          break
        end
      end
      # Just a little Bug detection mechanism ... never know.
      if (!lFound)
        puts "!!! Object #{iObject} should have been inserted under node #{iParentNodeID}). However no trace of this object in the children nodes. Bug ?"
      end
    end

    # Fill the tree view by scratching it first.
    def fillMainTree
      updateMainTree do
        # Update it
        # Erase everything
        @TCMainTree.delete_all_items
        # Create root
        @RootID = @TCMainTree.add_root('     ')
        # Keep a correspondance of each Tag and its corresponding Tree ID
        # map< Tag, Integer >
        @TagsToMainTree = { @Controller.RootTag => @RootID }
        # Insert each tag
        @Controller.RootTag.Children.each do |iTag|
          insertTreeBranch(@RootID, iTag)
        end
        # Insert each Shortcut that does not have any tag
        @Controller.ShortcutsList.each do |iSC|
          if (iSC.Tags.empty?)
            lSCNodeID = @TCMainTree.append_item(@RootID, '')
            @TCMainTree.set_item_data(lSCNodeID, [ID_SHORTCUT, iSC])
            updateMainTreeNode(lSCNodeID)
          end
        end
        @TCMainTree.expand(@RootID)
      end
    end

    # Notify the GUI that data on the currently opened file has been modified
    def onCurrentOpenedFileUpdate
      setAppTitle
    end

    # Notify the GUI that an update has occured on a Tag
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag that was modified
    def onTagContentUpdate(iTag)
      # We update the tree accordingly
      updateMainTree do
        lTagID = @TagsToMainTree[iTag]
        if (lTagID == nil)
          puts '!!! The updated Tag was not inserted in the main tree. Bug ?'
        else
          updateMainTreeNode(lTagID)
        end
      end
    end

    # Notify that a given Tag's children list has changed
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The Tag whose children list has changed
    # * *iOldChildrenList* (<em>list<Tag></em>): The old children list
    def onTagChildrenUpdate(iParentTag, iOldChildrenList)
      # We update the tree accordingly
      updateMainTree do
        lTagID = @TagsToMainTree[iParentTag]
        if (lTagID == nil)
          puts '!!! The updated Tag was not inserted in the main tree. Bug ?'
        else
          # First remove Tags that are not part of the children anymore
          @TCMainTree.children(lTagID).each do |iChildID|
            lID, lObject = @TCMainTree.get_item_data(iChildID)
            if (lID == ID_TAG)
              if (!iParentTag.Children.include?(lObject))
                # We have to remove iChildID from the tree, along with all its children
                removeTreeBranch(iChildID)
              end
            end
          end
          # Then add new Tags
          iParentTag.Children.each do |iChildTag|
            lChildID = @TagsToMainTree[iChildTag]
            if (lChildID == nil)
              # We have to insert iChildTag, and all Shortcuts and children Tags associated to it
              insertTreeBranch(lTagID, iChildTag)
            end
          end
        end
      end
    end

    # A Shortcut has just been added
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The added Shortcut
    def onShortcutAdd(iSC)
      # We update the tree accordingly
      updateMainTree do
        addShortcutInfoToMainTree(iSC)
      end
    end

    # A Shortcut has just been deleted
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The deleted Shortcut
    def onShortcutDelete(iSC)
      # We update the tree accordingly
      updateMainTree do
        if (iSC.Tags.empty?)
          # Delete it from root
          deleteObjectFromTree(@RootID, iSC)
        else
          # For each Tag this Shortcut was belonging to, we will delete its node
          iSC.Tags.each do |iTag, iNil|
            lTagNodeID = @TagsToMainTree[iTag]
            if (lTagNodeID == nil)
              puts "!!! Tag #{iTag.getUniqueID.join('/')} should have been inserted in the main tree. However it is not registered. Bug ?"
            else
              deleteObjectFromTree(lTagNodeID, iSC)
            end
          end
        end
      end
    end

    # An update has occured on a Shortcut's data
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut whose data was invalidated
    # * *iOldSCID* (_Integer_): The Shortcut ID before data modification
    # * *iOldContent* (_Object_): The previous content, or nil if it was not modified
    # * *iOldMetadata* (_Object_): The previous metadata, or nil if it was not modified
    def onShortcutDataUpdate(iSC, iOldSCID, iOldContent, iOldMetadata)
      # We update the tree accordingly
      updateMainTree do
        # Just retrieve existing nodes and update them
        @TCMainTree.traverse do |iItemID|
          lID, lObject = @TCMainTree.get_item_data(iItemID)
          if (lObject == iSC)
            # Update iItemID with the new info from iSC
            updateMainTreeNode(iItemID)
          end
        end
      end
    end

    # An update has occured on a Shortcut's Tags
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut whose Tags were invalidated
    # * *iOldTags* (<em>map<Tag,nil></em>): The old Tags set
    def onShortcutTagsUpdate(iSC, iOldTags)
      # We update the tree accordingly
      updateMainTree do
        # First, delete any reference to iSC
        lSCID = iSC.getUniqueID
        lToBeDeleted = []
        @TCMainTree.traverse do |iItemID|
          lID, lObject = @TCMainTree.get_item_data(iItemID)
          if ((lObject != nil) and
              (lObject.getUniqueID == lSCID))
            lToBeDeleted << iItemID
          end
        end
        lToBeDeleted.each do |iItemID|
          @TCMainTree.delete(iItemID)
        end
        # Then add iSC everywhere needed
        addShortcutInfoToMainTree(iSC)
      end
    end

    # All Shortcuts/Tags data has been replaced
    def onReplaceAll
      fillMainTree
    end

    # Get the currently selected object and its ID from the main tree
    #
    # Return:
    # * _Integer_: Object ID (or nil if none selected)
    # * _Object_: Object (or nil if none selected)
    def getCurrentTreeSelection
      rID = nil
      rObject = nil

      # Get the selection from the main tree
      lSelectionID = @TCMainTree.selection
      if (lSelectionID == 0)
        puts '!!! No selection in the Tree.'
      else
        rID, rObject = @TCMainTree.get_item_data(lSelectionID)
      end

      return rID, rObject
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

      # Register this Event as otherwise moving the mouse over the TreeCtrl component generates tons of warnings. Bug ?
      Wx::EvtHandler::EVENT_TYPE_CLASS_MAP[10000] = Wx::Event

      evt_close do |iEvent|
        @Controller.notifyFinal
        self.destroy
      end

      # Create the treeview
      @TCMainTree = Wx::TreeCtrl.new(self)
      # fill the tree view from scratch
      fillMainTree

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
      @Controller.ImportPlugins.each do |iImportID, iImport|
        addMenuCommand(lImportMenu, ID_IMPORT_BASE + iImport.index)
      end
      lFileMenu.append_sub_menu(lImportMenu, 'Import')
      lImportMergeMenu = Wx::Menu.new
      @Controller.ImportPlugins.each do |iImportID, iImport|
        addMenuCommand(lImportMergeMenu, ID_IMPORT_MERGE_BASE + iImport.index)
      end
      lFileMenu.append_sub_menu(lImportMergeMenu, 'Import and Merge')
      lExportMenu = Wx::Menu.new
      @Controller.ExportPlugins.each do |iExportID, iExport|
        addMenuCommand(lExportMenu, ID_EXPORT_BASE + iExport.index)
      end
      lFileMenu.append_sub_menu(lExportMenu, 'Export')
      lFileMenu.append_separator
      addMenuCommand(lFileMenu, Wx::ID_EXIT)
      # Edit menu
      lEditMenu = Wx::Menu.new
      addMenuCommand(lEditMenu, Wx::ID_UNDO)
      addMenuCommand(lEditMenu, Wx::ID_REDO)
      lEditMenu.append_separator
      addMenuCommand(lEditMenu, Wx::ID_CUT)
      addMenuCommand(lEditMenu, Wx::ID_COPY) do |iEvent, oValidator|
        lID, lObject = getCurrentTreeSelection
        if (lID == nil)
          oValidator.setError('No selection in the Tree when invoking Copy.')
        else
          oValidator.authorizeCmd(
            :objectID => lID,
            :object => lObject
          )
        end
      end
      addMenuCommand(lEditMenu, Wx::ID_PASTE) do |iEvent, oValidator|
        lSelectedTag = nil
        lID, lObject = getCurrentTreeSelection
        if (lID == nil)
          puts '!!! No selection in the Tree when invoking Paste. Assuming we want to paste under the Root tag.'
          lSelectedTag = @Controller.RootTag
        else
          case lID
          when ID_TAG
            lSelectedTag = lObject
          when ID_SHORTCUT
            oValidator.setError('The selected item in the tree is a Shortcut. Please select a Tag before pasting.')
          else
            oValidator.setError("The selected item in the tree is neither a Shortcut nor a Tag (ID = #{lID}). Bug ?")
          end
        end
        if (lSelectedTag != nil)
          oValidator.authorizeCmd(
            :tag => lSelectedTag
          )
        end
      end
      addMenuCommand(lEditMenu, Wx::ID_DELETE) do |iEvent, oValidator|
        lID, lObject = getCurrentTreeSelection
        if (lID == nil)
          oValidator.setError('No selection in the Tree when invoking Delete.')
        else
          oValidator.authorizeCmd(
            :parentWindow => self,
            :objectID => lID,
            :object => lObject
          )
        end
      end
      lEditMenu.append_separator
      addMenuCommand(lEditMenu, Wx::ID_FIND)
      lEditMenu.append_separator
      lNewSCsMenu = Wx::Menu.new
      @Controller.TypesPlugins.each do |iTypeID, iType|
        addMenuCommand(lNewSCsMenu, ID_NEW_SHORTCUT_BASE + iType.index)
      end
      lEditMenu.append_sub_menu(lNewSCsMenu, 'New Shortcut')
      addMenuCommand(lEditMenu, ID_EDIT_SHORTCUT) do |iEvent, oValidator|
        lID, lObject = getCurrentTreeSelection
        if (lID == nil)
          oValidator.setError('No selection in the Tree when invoking Edit Shortcut.')
        else
          case lID
          when ID_SHORTCUT
            oValidator.authorizeCmd(
              :parentWindow => self,
              :shortcut => lObject
            )
          else
            oValidator.setError("No shortcut selected in the Tree when invoking Edit Shortcut (Node #{lSelectedSCID}, ID = #{lID}).")
          end
        end
      end
      lEditMenu.append_separator
      addMenuCommand(lEditMenu, ID_NEW_TAG)
      addMenuCommand(lEditMenu, ID_EDIT_TAG)
      # Setup menu
      lSetupMenu = Wx::Menu.new
      addMenuCommand(lSetupMenu, ID_TAGS_EDITOR)
      addMenuCommand(lSetupMenu, ID_TYPES_CONFIG)
      addMenuCommand(lSetupMenu, ID_KEYMAPS)
      addMenuCommand(lSetupMenu, ID_ENCRYPTION)
      addMenuCommand(lSetupMenu, ID_TOOLBARS)
      lIntPluginsMenu = Wx::Menu.new
      @Controller.IntegrationPlugins.each do |iIntID, iInt|
        addMenuCommand(lIntPluginsMenu, ID_INTEGRATION_BASE + iInt.index)
      end
      lSetupMenu.append_sub_menu(lIntPluginsMenu, 'Integration plugins')
      # Tools menu
      lToolsMenu = Wx::Menu.new
      addMenuCommand(lToolsMenu, ID_STATS)
      # Help menu
      lHelpMenu = Wx::Menu.new
      addMenuCommand(lHelpMenu, Wx::ID_HELP)
      addMenuCommand(lHelpMenu, Wx::ID_ABOUT)

      # Create the menu bar
      lMenu = Wx::MenuBar.new
      lMenu.append(lFileMenu, 'File')
      lMenu.append(lEditMenu, 'Edit')
      lMenu.append(lSetupMenu, 'Setup')
      lMenu.append(lToolsMenu, 'Tools')
      lMenu.append(lHelpMenu, 'Help')
      self.menu_bar = lMenu

      # Instantiate a default toolbar
      lDefaultToolBar = [
        Wx::ID_OPEN,
        Wx::ID_SAVEAS,
        Wx::ID_SEPARATOR,
        ID_EDIT_SHORTCUT,
        Wx::ID_UNDO,
        Wx::ID_REDO
      ]

      # Create the toolbar
      lToolBar = Wx::ToolBar.new(self,
        :style => Wx::TB_FLAT|Wx::TB_HORIZONTAL
      )
      lDefaultToolBar.each do |iCommandID|
        if (iCommandID == Wx::ID_SEPARATOR)
          lToolBar.add_separator
        else
          @Controller.addToolbarCommand(lToolBar, iCommandID)
        end
      end
      lToolBar.realize
      self.tool_bar = lToolBar

      # Create the status bar
      lStatusBar = Wx::StatusBar.new(self)
      self.status_bar = lStatusBar

      # Set the Accelerator table for this frame
      @Controller.setAcceleratorTableForFrame(self)

      # Don't forget the main icon
      self.icon = Wx::Icon.new("#{$PBSRootDir}/Graphics/Icon.png")

      # Set the application title, as it depends on context
      setAppTitle

    end

  end

end
