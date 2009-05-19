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
      lID, lObjectID = @TCMainTree.get_item_data(iItemID)
      case lID
      when ID_TAG
        # Get the corresponding Tag
        lTag = @Controller.findTag(lObjectID)
        if (lTag == nil)
          puts "!!! Node #{iItemID} contains the Tag ID #{lObjectID.join('/')} but no Tag exists under this ID. The item will be marked as visible for error. Bug ?"
          @TCMainTree.set_item_text(iItemID, "!!! Unknown Tag #{lObjectID.join('/')}")
        else
          @TCMainTree.set_item_text(iItemID, lTag.Name)
          # Check the Copy/Cut markers
          if (@CopySelection != nil)
            if (@CopySelection.isTagPrimary?(lTag))
              if (@CopyMode == Wx::ID_CUT)
                @TCMainTree.set_item_image(iItemID, 0)
              else
                @TCMainTree.set_item_image(iItemID, 1)
              end
            elsif (@CopySelection.isTagSecondary?(lTag))
              if (@CopyMode == Wx::ID_CUT)
                @TCMainTree.set_item_image(iItemID, 2)
              else
                @TCMainTree.set_item_image(iItemID, 3)
              end
            else
              @TCMainTree.set_item_image(iItemID, -1)
            end
          else
            @TCMainTree.set_item_image(iItemID, -1)
          end
        end
      when ID_SHORTCUT
        # Retrieve the Shortcut
        lShortcut = @Controller.findShortcut(lObjectID)
        if (lShortcut == nil)
          puts "!!! Node #{iItemID} contains the Shortcut ID #{lObjectID} but no Shortcut exists under this ID. The item will be marked as visible for error. Bug ?"
          @TCMainTree.set_item_text(iItemID, "!!! Unknown Shortcut #{lObjectID}")
        else
          lTitle = lShortcut.Metadata['title']
          if (lTitle == nil)
            lTitle = '-- Unknown title --'
          end
          @TCMainTree.set_item_text(iItemID, lTitle)
          # Check the Copy/Cut markers
          if (@CopySelection != nil)
            lParentTag = getParentTag(iItemID)
            if (@CopySelection.isShortcutPrimary?(lShortcut, lParentTag))
              if (@CopyMode == Wx::ID_CUT)
                @TCMainTree.set_item_image(iItemID, 0)
              else
                @TCMainTree.set_item_image(iItemID, 1)
              end
            elsif (@CopySelection.isShortcutSecondary?(lShortcut, lParentTag))
              if (@CopyMode == Wx::ID_CUT)
                @TCMainTree.set_item_image(iItemID, 2)
              else
                @TCMainTree.set_item_image(iItemID, 3)
              end
            else
              @TCMainTree.set_item_image(iItemID, -1)
            end
          else
            @TCMainTree.set_item_image(iItemID, -1)
          end
        end
      else
        puts "!!! Tree node #{iItemID} has unknown ID (#{lID}). It will be marked in the tree. Bug ?"
        @TCMainTree.set_item_text(iItemID, "!!! Unknown Data ID (Node ID: #{iItemID}, Data ID: #{lID}) !!!")
      end
      if ($PBS_DevDebug)
        # Add some debugging info
        @TCMainTree.set_item_text(iItemID, "#{@TCMainTree.get_item_text(iItemID)} (ID=#{lID}, ObjectID=#{lObjectID}, NodeID=#{iItemID})")
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
      lID, lObjectID = @TCMainTree.get_item_data(iNodeID)
      case lID
      when ID_TAG
        # Remove a Tag reference
        lNodeID = @TagsToMainTree.delete(lObjectID)
        if (lNodeID != iNodeID)
          puts "!!! We are removing node ID #{iNodeID}, referenced for Tag #{lObjectID.join('/')}, but this Tag ID was registered for another node of ID #{lNodeID}."
        end
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
      @TCMainTree.set_item_data(lTagNodeID, [ ID_TAG, iTag.getUniqueID ])
      @TagsToMainTree[iTag.getUniqueID] = lTagNodeID
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
          @TCMainTree.set_item_data(lSCNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
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
        @TCMainTree.set_item_data(lNewNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
        updateMainTreeNode(lNewNodeID)
      else
        iSC.Tags.each do |iTag, iNil|
          lTagID = @TagsToMainTree[iTag.getUniqueID]
          if (lTagID == nil)
            puts "!!! Shortcut #{iSC.Metadata['title']} is tagged with #{iTag.Name}, which does not exist in the known tags."
          else
            lNewNodeID = @TCMainTree.append_item(lTagID, '')
            @TCMainTree.set_item_data(lNewNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
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
        lID, lObjectID = @TCMainTree.get_item_data(iChildNodeID)
        if (lObjectID == iObject.getUniqueID)
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
        @TCMainTree.set_item_data(@RootID, [ ID_TAG, @Controller.RootTag.getUniqueID ] )
        # Keep a correspondance of each Tag and its corresponding Tree ID
        # map< Tag, Integer >
        @TagsToMainTree = { @Controller.RootTag.getUniqueID => @RootID }
        # Insert each tag
        @Controller.RootTag.Children.each do |iTag|
          insertTreeBranch(@RootID, iTag)
        end
        # Insert each Shortcut that does not have any tag
        @Controller.ShortcutsList.each do |iSC|
          if (iSC.Tags.empty?)
            lSCNodeID = @TCMainTree.append_item(@RootID, '')
            @TCMainTree.set_item_data(lSCNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
            updateMainTreeNode(lSCNodeID)
          end
        end
        @TCMainTree.expand(@RootID)
        if ($PBS_DevDebug)
          @TCMainTree.expand_all
        end
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
        lTagID = @TagsToMainTree[iTag.getUniqueID]
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
        lTagID = @TagsToMainTree[iParentTag.getUniqueID]
        if (lTagID == nil)
          puts '!!! The updated Tag was not inserted in the main tree. Bug ?'
        else
          # First remove Tags that are not part of the children anymore
          @TCMainTree.children(lTagID).each do |iChildID|
            lID, lObjectID = @TCMainTree.get_item_data(iChildID)
            if (lID == ID_TAG)
              # Check if lObjectID is part of the children of iParentTag
              lFound = false
              iParentTag.Children.each do |iChildTag|
                if (iChildTag.getUniqueID == lObjectID)
                  lFound = true
                  break
                end
              end
              if (!lFound)
                # We have to remove iChildID from the tree, along with all its children
                removeTreeBranch(iChildID)
              end
            end
          end
          # Then add new Tags
          iParentTag.Children.each do |iChildTag|
            lChildID = @TagsToMainTree[iChildTag.getUniqueID]
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
            lTagNodeID = @TagsToMainTree[iTag.getUniqueID]
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
          lID, lObjectID = @TCMainTree.get_item_data(iItemID)
          if (lObjectID == iOldSCID)
            # Update iItemID with the new info from iSC
            updateMainTreeNode(iItemID)
            # Store the new ID
            @TCMainTree.set_item_data(iItemID, iSC.getUniqueID)
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
          lID, lObjectID = @TCMainTree.get_item_data(iItemID)
          if (lObjectID == lSCID)
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

    # Update all items affected by a multiple selection
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    def refreshSelectedItems(iSelection)
      # Update each item impacted by this selection
      updateMainTree do
        (iSelection.SelectedPrimaryShortcuts + iSelection.SelectedSecondaryShortcuts).each do |iSCInfo|
          iSCID, iParentTagID = iSCInfo
          # Find the node of the Tag
          lParentNodeID = @TagsToMainTree[iParentTagID]
          # Check each child, and update the one for our Shortcut
          @TCMainTree.children(lParentNodeID).each do |iChildNodeID|
            # If this child is for our SC, update it
            lID, lObjectID = @TCMainTree.get_item_data(iChildNodeID)
            if (lObjectID == iSCID)
              updateMainTreeNode(iChildNodeID)
            end
          end
        end
        (iSelection.SelectedPrimaryTags + iSelection.SelectedSecondaryTags).each do |iTagID|
          # Find the node of the Tag
          lTagNodeID = @TagsToMainTree[iTagID]
          updateMainTreeNode(lTagNodeID)
        end
      end
    end

    # A selection has been copied
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def onObjectsCopied(iSelection)
      @CopySelection = iSelection
      @CopyMode = Wx::ID_COPY
      refreshSelectedItems(@CopySelection)
    end

    # A selection has been cut
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def onObjectsCut(iSelection)
      @CopySelection = iSelection
      @CopyMode = Wx::ID_CUT
      refreshSelectedItems(@CopySelection)
    end

    # A marked to be copied/cut object has been cancelled
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def onCancelCopy(iSelection)
      lOldSelection = @CopySelection
      @CopySelection = nil
      @CopyMode = nil
      refreshSelectedItems(lOldSelection)
    end

    # A marked to be cut selection has been effecively cut.
    # This notifications comes after having deleted the object already. So its goal is to only remove some context the GUI could have stored regarding the Cut operation.
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The copied selection
    def onCutPerformed(iSelection)
      @CopySelection = nil
      @CopyMode = nil
    end

    # Display some debugging info
    def onDevDebug
      puts '=== Correspondace between Tag IDs and Node IDs:'
      @TagsToMainTree.each do |iTagID, iNodeID|
        puts "#{iTagID.join('/')} => #{iNodeID}"
      end
    end

    # Get the Tag corresponding to the parent of a node
    #
    # Parameters:
    # * *iNodeID* (_Integer_): The node whose parent we want
    # Return:
    # * _Tag_: The Tag corresponding to the parent node (nil for the Root Tag)
    def getParentTag(iNodeID)
      rParentTag = nil

      lParentNodeID = @TCMainTree.get_item_parent(iNodeID)
      lParentID, lParentTagID = @TCMainTree.get_item_data(lParentNodeID)
      if (lParentID != ID_TAG)
        puts "Parent node #{lParentNodeID} should be flagged as a Tag, but is flagged as #{lParentID}. Bug ?"
      else
        rParentTag = @Controller.findTag(lParentTagID)
        if (rParentTag == nil)
          puts "!!! Tag #{lParentTagID.join('/')} should be present in the data. Bug ?"
        end
      end

      return rParentTag
    end

    # Return if the main tree selection has effectively changed compared to last time
    #
    # Return:
    # * _Boolean_: Has main tree selection changed ?
    def mainTreeSelectionChanged?
      rResult = false

      lSelection = @TCMainTree.selections
      if (lSelection != @OldMainTreeSelection)
        @OldMainTreeSelection = lSelection
        rResult = true
      end

      return rResult
    end

    # Get the currently selected object and its ID from the main tree
    #
    # Return:
    # * _MultipleSelection_: The selection
    def getCurrentTreeSelection
      rSelection = MultipleSelection.new(@Controller)

      # Get the selection from the main tree
      @TCMainTree.selections.each do |iSelectionID|
        lID, lObjectID = @TCMainTree.get_item_data(iSelectionID)
        case lID
        when ID_TAG
          lTag = @Controller.findTag(lObjectID)
          if (lTag == nil)
            puts "!!! The main tree has a selection of the Tag ID #{lObjectID.join('/')}, but we can't find it in the data. Bug ?"
          else
            rSelection.selectTag(lTag)
          end
        when ID_SHORTCUT
          lSC = @Controller.findShortcut(lObjectID)
          if (lSC == nil)
            puts "!!! The main tree has a selection of the Shortcut ID #{lObjectID}, but we can't find it in the data. Bug ?"
          else
            # Get the parent Tag
            lParentTag = getParentTag(iSelectionID)
            rSelection.selectShortcut(lSC, lParentTag)
          end
        else
          puts "!!! One of the selected items has an unknown ID (#{lID}). Bug ?"
        end
      end

      return rSelection
    end

    # Method called when the selection of the main tree has changed
    def onMainTreeSelectionUpdated
      if (mainTreeSelectionChanged?)
        lSelection = getCurrentTreeSelection
        lName = lSelection.getDescription
        # Enable and change titles of Cut/Copy/Delete
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
        # Enable and change title of Edit
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
        # Enable and change title of Paste
        @Controller.setMenuItemGUIEnabled(@EditMenu, Wx::ID_PASTE, lSelection.singleTag?)
        lButton = @ToolBar.find_by_id(Wx::ID_PASTE)
        if (lButton != nil)
          @Controller.setToolbarButtonGUIEnabled(lButton, Wx::ID_PASTE, lSelection.singleTag?)
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

      # Register this Event as otherwise moving the mouse over the TreeCtrl component generates tons of warnings. Bug ?
      Wx::EvtHandler::EVENT_TYPE_CLASS_MAP[10000] = Wx::Event

      # The close event
      evt_close do |iEvent|
        @Controller.notifyFinal
        self.destroy
      end

      # Cut/Copy markers
      @CopySelection = nil
      @CopyMode = nil

      # Create the treeview
      @TCMainTree = Wx::TreeCtrl.new(self,
        :style => Wx::TR_HAS_BUTTONS|Wx::TR_MULTIPLE
      )
      @OldMainTreeSelection = nil
      # Create the image list for the tree
      lImageList = createImageList(['MiniCut.png', 'MiniCopy.png', 'MicroCut.png', 'MicroCopy.png'])
      @TCMainTree.image_list = lImageList
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
      @EditMenu = Wx::Menu.new
      addMenuCommand(@EditMenu, Wx::ID_UNDO)
      addMenuCommand(@EditMenu, Wx::ID_REDO)
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, Wx::ID_CUT) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :selection => getCurrentTreeSelection
        )
      end
      addMenuCommand(@EditMenu, Wx::ID_COPY) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :selection => getCurrentTreeSelection
        )
      end
      addMenuCommand(@EditMenu, Wx::ID_PASTE) do |iEvent, oValidator|
        # Here, we are sure the selection is on 1 Tag only
        lSelectedTag = @Controller.findTag(getCurrentTreeSelection.SelectedPrimaryTags[0])
        if (lSelectedTag == nil)
          oValidator.setError("Normally a single Tag was selected: #{getCurrentTreeSelection.getDescription}. However we are unable to retrieve it. Bug ?")
        else
          oValidator.authorizeCmd(
            :tag => lSelectedTag
          )
        end
      end
      addMenuCommand(@EditMenu, Wx::ID_DELETE) do |iEvent, oValidator|
        oValidator.authorizeCmd(
          :selection => getCurrentTreeSelection,
          :parentWindow => self
        )
      end
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, Wx::ID_FIND)
      @EditMenu.append_separator
      lNewSCsMenu = Wx::Menu.new
      @Controller.TypesPlugins.each do |iTypeID, iType|
        addMenuCommand(lNewSCsMenu, ID_NEW_SHORTCUT_BASE + iType.index)
      end
      @EditMenu.append_sub_menu(lNewSCsMenu, 'New Shortcut')
      addMenuCommand(@EditMenu, Wx::ID_EDIT) do |iEvent, oValidator|
        # We are sure a single Tag or a single Shortcut are selected
        lSelection = getCurrentTreeSelection
        if (lSelection.singleTag?)
          # A Tag is selected
          lSelectedTag = @Controller.findTag(lSelection.SelectedPrimaryTags[0])
          if (lSelectedTag == nil)
            oValidator.setError("Normally a single Tag was selected: #{lSelection.getDescription}. However we are unable to retrieve it. Bug ?")
          else
            oValidator.authorizeCmd(
              :parentWindow => self,
              :objectID => ID_TAG,
              :object => lSelectedTag
            )
          end
        elsif (lSelection.singleShortcut?)
          # A Shortcut is selected
          lSelectedSC = @Controller.findShortcut(lSelection.SelectedPrimaryShortcuts[0][0])
          if (lSelectedSC == nil)
            oValidator.setError("Normally a single Shortcut was selected: #{lSelection.getDescription}. However we are unable to retrieve it. Bug ?")
          else
            oValidator.authorizeCmd(
              :parentWindow => self,
              :objectID => ID_SHORTCUT,
              :object => lSelectedSC
            )
          end
        else
          oValidator.setError("Normally a single Shortcut or Tag was selected: #{lSelection.getDescription}. However we are unable to retrieve it. Bug ?")
        end
      end
      @EditMenu.append_separator
      addMenuCommand(@EditMenu, ID_NEW_TAG)
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
      if ($PBS_DevDebug)
        addMenuCommand(lToolsMenu, ID_DEVDEBUG)
      end
      # Help menu
      lHelpMenu = Wx::Menu.new
      addMenuCommand(lHelpMenu, Wx::ID_HELP)
      addMenuCommand(lHelpMenu, Wx::ID_ABOUT)

      # Create the menu bar
      lMenu = Wx::MenuBar.new
      lMenu.append(lFileMenu, 'File')
      lMenu.append(@EditMenu, 'Edit')
      lMenu.append(lSetupMenu, 'Setup')
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

      # Don't forget the main icon
      self.icon = Wx::Icon.new("#{$PBSRootDir}/Graphics/Icon.png")

      # Set the application title, as it depends on context
      setAppTitle

      # Enables Copy/Cut/Delete/Edit/Paste depending on selected items in the tree
      evt_tree_sel_changed(@TCMainTree) do |iEvent|
        onMainTreeSelectionUpdated
      end
      evt_tree_get_info(@TCMainTree) do |iEvent|
        onMainTreeSelectionUpdated
      end

    end

  end

end
