#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# We cannot call the draw method on Wx::Bitmap objects that have been cloned. Bug ?
# Therefore we define a new one.
module Wx

  class Bitmap

    # Clone method
    # TODO (WxRuby): Delete when Wx::Bitmap.clone will exist
    #
    # Return:
    # * <em>Wx::Bitmap</em>: The clone
    def clone
      return Wx::Bitmap.from_image(convert_to_image)
    end

  end

end

module PBS

  # The main tree view, as a separate component.
  # This component can then be reused in other GUIs.
  class PBSTreeCtrl < Wx::TreeCtrl

    include Tools

    # Define flags that will then be used to identify which icons have to be drawn upon an item icon (ex. for Copy/Cut/Drag)
    # Those flags can then be combined into a bit mask.
    FLAG_PRIMARY_COPY = 1
    FLAG_PRIMARY_CUT = 2
    FLAG_SECONDARY_COPY = 4
    FLAG_SECONDARY_CUT = 8
    FLAG_DRAG = 16
    FLAG_DRAG_NONE = 32

    # Define bitmaps used for layers in the tree
    # !!! Be careful that all of these images MUST have a semi-transparent pixel in their data, otherwise drawing the bitmap on a DC completely ignores the mask. Bug ?
    BITMAPLAYER_PRIMARY_COPY = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/MiniCopy.png")
    BITMAPLAYER_PRIMARY_CUT = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/MiniCut.png")
    BITMAPLAYER_SECONDARY_COPY = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/MicroCopy.png")
    BITMAPLAYER_SECONDARY_CUT = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/MicroCut.png")
    BITMAPLAYER_DRAG = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/DragNDrop.png")
    BITMAPLAYER_DRAG_NONE = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/DragNDropCancel.png")

    # Define default Tag and Shortcuts icons
    ICON_DEFAULT_TAG = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Tag.png")
    ICON_DEFAULT_SHORTCUT = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Shortcut.png")
    ICON_ROOT_TAG = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/MiniIcon.png")

    # The class defining the behaviour of the main tree for drop operations
    class SelectionDropTarget < Wx::DropTarget

      include Tools

      # Constructor
      #
      # Parameters:
      # * *iController* (_Controller_): The data model controller
      # * *iPBSTreeCtrl* (_PBSTreeCtrl_): The PBS tree component that uses this drop target
      def initialize(iController, iPBSTreeCtrl)
        @Controller = iController
        @PBSTreeCtrl = iPBSTreeCtrl
        @Data = Tools::DataObjectSelection.new
        # Cache of the last [ hovered Tags / Suggested results / Locally Dragged Selection flag ] => Given result, Errors list (nil if no error)
        # We include the flag about the Locally Dragged Selection in the key of the cache, because the DropSource.give_feedback is called after the first call to DropTarget.on_drag_over: therefore @Controller.DragSelection is still nil when on_drag_over fills the cache for the first time.
        # map< [ Tag, Integer, Boolean ], [ Integer, list< String > ] >
        @Cache_LastHoveredTags = {}
        # Cache of the last given result for the last hovered Tag and
        super(@Data)
      end

      # Called when the mouse is being dragged over the drop target. By default, this calls functions return the suggested return value def.
      # Use a cache of the last hovered item (otherwise it would be far too much CPU consuming as on_drag_over is always repeatedly called even if the mous does not move).
      #
      # Parameters:
      # * *iMouseX* (_Integer_): The x coordinate of the mouse.
      # * *iMouseY* (_Integer_): The y coordinate of the mouse.
      # * *iSuggestedResult* (_Integer_): Suggested value for return value. Determined by SHIFT or CONTROL key states.
      # Return:
      # * _Integer_: Returns the desired operation or Wx::DragNone. This is used for optical feedback from the side of the drop source, typically in form of changing the icon.
      def on_drag_over(iMouseX, iMouseY, iSuggestedResult)
        lHoveredTag = @PBSTreeCtrl.getHoveredTag(Wx::Point.new(iMouseX, iMouseY))
        if (lHoveredTag == nil)
          return Wx::DRAG_NONE
        else
          lCacheKey = [ lHoveredTag, iSuggestedResult, @Controller.DragSelection != nil ]
          if (@Cache_LastHoveredTags[lCacheKey] == nil)
            # Compute the result we want to give for lHoveredTag, iSuggestedResult
            # Use a temporary MultipleSelection object
            lSelection = nil
            if (lHoveredTag != @Controller.RootTag)
              # Create a MultipleSelection to call isPasteAuthorized?
              lSelection = MultipleSelection.new(@Controller)
              lSelection.selectTag(lHoveredTag)
            end
            lCopyMode = nil
            case iSuggestedResult
            when Wx::DRAG_MOVE
              lCopyMode = Wx::ID_CUT
            when Wx::DRAG_COPY
              lCopyMode = Wx::ID_COPY
            else
              put "!!! Unknown suggested result: #{iSuggestedResult}"
            end
            lPasteOK, lErrors = isPasteAuthorized?(
              @Controller,
              lSelection,
              lCopyMode,
              @Controller.DragSelection,
              nil,
              nil
            )
            if (lPasteOK)
              @Cache_LastHoveredTags[lCacheKey] = [ iSuggestedResult, nil ]
            else
              @Cache_LastHoveredTags[lCacheKey] = [ Wx::DRAG_NONE, lErrors ]
            end
          end
          rResult, lErrors = @Cache_LastHoveredTags[lCacheKey]
          # TODO: Use lErrors in the DragImage
          return rResult
        end
      end

      # Called after on_drop returns true. By default this will usually get_data and will return the suggested default value.
      #
      # Parameters:
      # * *iMouseX* (_Integer_): The x coordinate of the mouse.
      # * *iMouseY* (_Integer_): The y coordinate of the mouse.
      # * *iSuggestedResult* (_Integer_): Suggested value for return value. Determined by SHIFT or CONTROL key states.
      # Return:
      # * _Integer_: Returns the desired operation or Wx::DragNone. This is used for optical feedback from the side of the drop source, typically in form of changing the icon.
      def on_data(iMouseX, iMouseY, iSuggestedResult)
        # Read what is being dragged in the source
        get_data
        lCopyType, lCopyID, lSerializedTags, lSerializedShortcuts = @Data.getData
        # Get the selected Tag to paste into
        lSelectedTag = @PBSTreeCtrl.getHoveredTag(Wx::Point.new(iMouseX, iMouseY))
        # Check that we can effectively drop here.
        # Problem is that we can't check it completely during on_drag_over, as it is impossible to get the data at that time.
        # Use a temporary MultipleSelection object
        lSelection = nil
        if (lSelectedTag != @Controller.RootTag)
          # Create a MultipleSelection to call isPasteAuthorized?
          lSelection = MultipleSelection.new(@Controller)
          lSelection.selectTag(lSelectedTag)
        end
        lCopyMode = nil
        case iSuggestedResult
        when Wx::DRAG_MOVE
          lCopyMode = Wx::ID_CUT
        when Wx::DRAG_COPY
          lCopyMode = Wx::ID_COPY
        else
          put "!!! Unknown suggested result: #{iSuggestedResult}"
        end
        lPasteOK, lErrors = isPasteAuthorized?(
          @Controller,
          lSelection,
          lCopyMode,
          @Controller.DragSelection,
          lSerializedTags,
          lSerializedShortcuts
        )
        if (lPasteOK)
          @Controller.undoableOperation("Paste #{Tools::MultipleSelection.getDescription(lSerializedTags, lSerializedShortcuts)} in #{lSelectedTag.Name}") do
            @Controller.mergeSerializedTagsShortcuts(lSelectedTag, lSerializedTags, lSerializedShortcuts)
            # Mark as modified
            @Controller.setCurrentFileModified
          end
          return iSuggestedResult
        else
          puts "!!! Can't drop because of #{lErrors.size} errors:"
          lErrors.each do |iError|
            puts "!!! #{iError}"
          end
          return Wx::DRAG_NONE
        end
      end

      # Called when the user drops a data object on the target. Return false to veto the operation.
      #
      # Parameters:
      # * *iMouseX* (_Integer_): The x coordinate of the mouse.
      # * *iMouseY* (_Integer_): The y coordinate of the mouse.
      # Return:
      # * _Boolean_: true to accept the data, false to veto the operation.
      def on_drop(iMouseX, iMouseY)
        # Here we are certain that we can drop, all the checks have been made in on_drag_over
        return true
      end

    end

    # Constructor
    #
    # Parameters:
    # * *iController* (_Controller_): The data model controller
    # * *iWindow* (<em>Wx::Window</em>): The parent window
    def initialize(iController, iWindow)
      # We can edit labels, we will forward modifications to either Tag.Name or Shortcut.Metadata['title']
      # We have little + buttons to collapse/expand
      # We have multiple selection
      super(iWindow,
        :style => Wx::TR_EDIT_LABELS|Wx::TR_HAS_BUTTONS|Wx::TR_MULTIPLE
      )

      # TODO (WxRuby): Bug correction
      # Register this Event as otherwise moving the mouse over the TreeCtrl component generates tons of warnings. Bug ?
      Wx::EvtHandler::EVENT_TYPE_CLASS_MAP[10000] = Wx::Event

      @Controller = iController
      # Selection in the clipboard
      # MultipleSelection
      @CopySelection = nil
      # Selection mode in the clipboard
      # Integer
      @CopyMode = nil
      # Selection in the drag'n'drop
      # MultipleSelection
      @DragSelection = nil
      # Selection mode in the drag'n'drop
      # Integer
      @DragMode = nil
      # The last known selection
      # MultipleSelection
      @OldSelection = nil
      # The last hovered node ID
      # Integer
      @OldHoveredNodeID = nil
      # The Root ID
      # Integer
      @RootID = nil
      # The Tags ID references to tree nodes
      # map< list<String>, Integer >
      @TagsToMainTree = nil
      # The drag image
      # Wx::DragImage
      @DragImage = nil
      # The context menu
      # Wx::Menu
      @ContextMenu = nil
      # Create the image list for the tree
      @ImageListManager = ImageListManager.new(self, 16, 16)
      # Accept incoming drops of things
      # Keep a reference to the DropTarget, as otherwise it results in a core dump when dragging over the tree (another way to avoid this reference is to use drop_target= instead of set_drop_target). Bug ?
      self.drop_target = SelectionDropTarget.new(@Controller, self)
      # fill the tree view from scratch
      fillTree

      # Begin drag event
      evt_tree_begin_drag(self) do |iEvent|
        # We begin dragging with left mouse
        lSelection = getCurrentSelection
        if (!lSelection.empty?)
          computeDragImage(lSelection)
          # Create the data DropSource
          lDragSource = SelectionDropSource.new(@DragImage, self, lSelection, @Controller)
          # Perform the complete DragNDrop
          lDropResult = lDragSource.do_drag_drop(Wx::DRAG_ALLOW_MOVE)
          # Notify that drag has ended
          @Controller.notifyObjectsDragEnd(lDropResult)
          # Check result
          if (lDropResult == Wx::DRAG_MOVE)
            # We delete the selection we have just dragged
            @Controller.cmdDelete({
                :parentWindow => nil,
                :selection => lSelection,
                :deleteTaggedShortcuts => false,
                :deleteOrphanShortcuts => false
              })
          end
          # Remove dragging image
          @DragImage.end_drag
        end
        iEvent.skip
      end
      evt_tree_begin_rdrag(self) do |iEvent|
        # We begin dragging with right mouse
        # TODO: Implement it with wxWidgets 2.9.0 (should be there May 2009)
        iEvent.skip
      end
      # The context menu
      evt_tree_item_menu(self) do |iEvent|
        popup_menu(@ContextMenu)
      end
      # Editing a label of a Tag or Shortcut
      evt_tree_begin_label_edit(self) do |iEvent|
        # We can't edit the Root
        if (iEvent.item == @RootID)
          iEvent.veto
        else
          iEvent.skip
        end
      end
      evt_tree_end_label_edit(self) do |iEvent|
        # First, retrieve who we are editing (we are sure it can't be the root)
        lID, lObjectID = get_item_data(iEvent.item)
        lNewName = iEvent.label
        if (lNewName.strip != '')
          case lID
          when ID_TAG
            lTag = @Controller.findTag(lObjectID)
            if (lNewName != lTag.Name)
              # We first check that an existing Tag does not already get the name
              if ((lTag.Parent != nil) and
                  (lTag.Parent.searchTag([lNewName]) != nil))
                puts "!!! Tag #{lTag.Parent.Name} has already a sub-Tag named #{lNewName}. Ignoring modifications."
                iEvent.veto
              else
                @Controller.undoableOperation("Edit Tag's name #{lTag.Name}") do
                  @Controller.modifyTag(lTag, lNewName, lTag.Icon)
                  @Controller.setCurrentFileModified
                end
              end
            end
          when ID_SHORTCUT
            lSC = @Controller.findShortcut(lObjectID)
            if (lNewName != lSC.Metadata['title'])
              @Controller.undoableOperation("Edit Shortcut's name #{lSC.Metadata['title']}") do
                lNewMetadata = lSC.Metadata.clone
                lNewMetadata['title'] = lNewName
                @Controller.modifyShortcut(lSC, lSC.Content, lNewMetadata, lSC.Tags)
                @Controller.setCurrentFileModified
              end
            end
          else
            puts "!!! We are editing an item of unknown ID: #{lID}. Bug ?"
          end
        end
      end
    end

    # Set the context menu
    #
    # Parameters:
    # * *iContextMenu* (<em>Wx::Menu</em>): The context menu to display on item right-click
    def setContextMenu(iContextMenu)
      @ContextMenu = iContextMenu
    end

    # Compute the drag image to use
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The new selection for the new drag image
    def computeDragImage(iSelection)
      # 1. Create the bitmap
      # Get the bitmap from the selection
      lSelectionBitmap = iSelection.getBitmap(font) do |ioBitmap, iWidth, iHeight|
        # Nothing to modify in the image so far.
        # Return the new width and height if greater
        next iWidth, iHeight
      end
      # 2. Cancel the previous drag image
      if (@DragImage != nil)
        @DragImage.end_drag
      end
      # 3. Create the new drag image
      @DragImage = Wx::DragImage.new(lSelectionBitmap)
      lScreenMainTreePos = client_to_screen(Wx::Point.new(0,0))
      @DragImage.begin_drag(Wx::Point.new( lSelectionBitmap.width/2 + lScreenMainTreePos.x, lSelectionBitmap.height/2 + lScreenMainTreePos.y), self, true)
      @DragImage.show
    end

    # Apply bitmap layers based on flags on a given bitmap
    #
    # Parameters:
    # * *ioBitmap* (<em>Wx::Bitmap</em>): The bitmap to modify
    # * *iFlags* (_Integer_): The flags used for modification
    def applyBitmapLayers(ioBitmap, iFlags)
      # 1. Create the bitmap that will be used as a mask
      lMaskBitmap = Wx::Bitmap.new(ioBitmap.width, ioBitmap.height, 1)
      lMaskBitmap.draw do |ioMaskDC|
        ioBitmap.draw do |iBitmapDC|
          ioMaskDC.blit(0, 0, ioBitmap.width, ioBitmap.height, iBitmapDC, 0, 0, Wx::SET, true)
        end
      end
      # 2. Remove the mask from the original bitmap
      lNoMaskBitmap = Wx::Bitmap.new(ioBitmap.width, ioBitmap.height, 1)
      lNoMaskBitmap.draw do |ioNoMaskDC|
        ioNoMaskDC.brush = Wx::WHITE_BRUSH
        ioNoMaskDC.pen = Wx::WHITE_PEN
        ioNoMaskDC.draw_rectangle(0, 0, ioBitmap.width, ioBitmap.height)
      end
      ioBitmap.mask = Wx::Mask.new(lNoMaskBitmap)
      # 3. Draw on the original bitmap and its mask
      ioBitmap.draw do |ioDC|
        lMaskBitmap.draw do |ioMaskDC|
          if (iFlags & FLAG_PRIMARY_COPY != 0)
            mergeBitmapOnDC(ioDC, ioMaskDC, BITMAPLAYER_PRIMARY_COPY)
          end
          if (iFlags & FLAG_PRIMARY_CUT != 0)
            mergeBitmapOnDC(ioDC, ioMaskDC, BITMAPLAYER_PRIMARY_CUT)
          end
          if (iFlags & FLAG_SECONDARY_COPY != 0)
            mergeBitmapOnDC(ioDC, ioMaskDC, BITMAPLAYER_SECONDARY_COPY)
          end
          if (iFlags & FLAG_SECONDARY_CUT != 0)
            mergeBitmapOnDC(ioDC, ioMaskDC, BITMAPLAYER_SECONDARY_CUT)
          end
          if (iFlags & FLAG_DRAG != 0)
            mergeBitmapOnDC(ioDC, ioMaskDC, BITMAPLAYER_DRAG)
          end
          if (iFlags & FLAG_DRAG_NONE != 0)
            mergeBitmapOnDC(ioDC, ioMaskDC, BITMAPLAYER_DRAG_NONE)
          end
        end
      end
      # 4. Set the mask correctly
      ioBitmap.mask = Wx::Mask.new(lMaskBitmap)
    end

    # Set one of tree's node attributes to fit its associated data (Tag or Shortcut).
    # Only this method knows how to display tree nodes.
    #
    # Parameters:
    # * *iItemID* (_Integer_): The item of the main tree that we want to update
    def updateTreeNode(iItemID)
      lID, lObjectID = get_item_data(iItemID)
      case lID
      when ID_TAG
        # Get the corresponding Tag
        lTag = @Controller.findTag(lObjectID)
        if (lTag == nil)
          puts "!!! Node #{iItemID} contains the Tag ID #{lObjectID.join('/')} but no Tag exists under this ID. The item will be marked as visible for error. Bug ?"
          set_item_text(iItemID, "!!! Unknown Tag #{lObjectID.join('/')}")
        else
          set_item_text(iItemID, lTag.Name)
          # Compute the flags to put on the icon
          # Integer
          lFlags = 0
          # Check the Copy/Cut markers
          if (@CopySelection != nil)
            if (@CopySelection.isTagPrimary?(lTag))
              if (@CopyMode == Wx::ID_CUT)
                lFlags |= FLAG_PRIMARY_CUT
              else
                lFlags |= FLAG_PRIMARY_COPY
              end
            end
            if (@CopySelection.isTagSecondary?(lTag))
              if (@CopyMode == Wx::ID_CUT)
                lFlags |= FLAG_SECONDARY_CUT
              else
                lFlags |= FLAG_SECONDARY_COPY
              end
            end
          elsif (@DragSelection != nil)
            if (@DragSelection.isTagPrimary?(lTag))
              if (@DragMode == Wx::DRAG_MOVE)
                lFlags |= FLAG_PRIMARY_CUT
                lFlags |= FLAG_DRAG
              elsif (@DragMode == Wx::DRAG_COPY)
                lFlags |= FLAG_PRIMARY_COPY
                lFlags |= FLAG_DRAG
              else
                lFlags |= FLAG_DRAG_NONE
              end
            end
            if (@DragSelection.isTagSecondary?(lTag))
              if (@DragMode == Wx::DRAG_MOVE)
                lFlags |= FLAG_SECONDARY_CUT
                lFlags |= FLAG_DRAG
              elsif (@DragMode == Wx::DRAG_COPY)
                lFlags |= FLAG_SECONDARY_COPY
                lFlags |= FLAG_DRAG
              else
                lFlags |= FLAG_DRAG_NONE
              end
            end
          end
          # Now compute the image ID
          lImageID = nil
          if (lTag.Icon != nil)
            # This image is unique to this Shortcut
            lImageID = [ lObjectID, lFlags ]
          else
            # This is the ID for Tags having no icon.
            lImageID = [ nil, lFlags ]
          end
          # Now compute the image based on lFlags and the object ID
          lIdxImage = @ImageListManager.getTreeImageIndex(lImageID) do
            if (lFlags == 0)
              # Just return the original icon, without modifications
              # Just return the original icon, without modifications
              if (lTag.Icon != nil)
                next lTag.Icon
              else
                next ICON_DEFAULT_TAG
              end
            else
              # We will apply some layers, so clone the original bitmap
              rBitmap = nil
              if (lTag.Icon != nil)
                rBitmap = lTag.Icon.clone
              else
                rBitmap = ICON_DEFAULT_TAG.clone
              end
              applyBitmapLayers(rBitmap, lFlags)
              next rBitmap
            end
          end
          set_item_image(iItemID, lIdxImage)
        end
      when ID_SHORTCUT
        # Retrieve the Shortcut
        lShortcut = @Controller.findShortcut(lObjectID)
        if (lShortcut == nil)
          puts "!!! Node #{iItemID} contains the Shortcut ID #{lObjectID} but no Shortcut exists under this ID. The item will be marked as visible for error. Bug ?"
          set_item_text(iItemID, "!!! Unknown Shortcut #{lObjectID}")
        else
          lTitle = lShortcut.Metadata['title']
          if (lTitle == nil)
            lTitle = '-- Unknown title --'
          end
          set_item_text(iItemID, lTitle)
          # Compute the flags to put on the icon
          # Integer
          lFlags = 0
          # Check the Copy/Cut markers
          if (@CopySelection != nil)
            lParentTag = getParentTag(iItemID)
            if (@CopySelection.isShortcutPrimary?(lShortcut, lParentTag))
              if (@CopyMode == Wx::ID_CUT)
                lFlags |= FLAG_PRIMARY_CUT
              else
                lFlags |= FLAG_PRIMARY_COPY
              end
            end
            if (@CopySelection.isShortcutSecondary?(lShortcut, lParentTag))
              if (@CopyMode == Wx::ID_CUT)
                lFlags |= FLAG_SECONDARY_CUT
              else
                lFlags |= FLAG_SECONDARY_COPY
              end
            end
          elsif (@DragSelection != nil)
            lParentTag = getParentTag(iItemID)
            if (@DragSelection.isShortcutPrimary?(lShortcut, lParentTag))
              if (@DragMode == Wx::DRAG_MOVE)
                lFlags |= FLAG_PRIMARY_CUT
                lFlags |= FLAG_DRAG
              elsif (@DragMode == Wx::DRAG_COPY)
                lFlags |= FLAG_PRIMARY_COPY
                lFlags |= FLAG_DRAG
              else
                lFlags |= FLAG_DRAG_NONE
              end
            end
            if (@DragSelection.isShortcutSecondary?(lShortcut, lParentTag))
              if (@DragMode == Wx::DRAG_MOVE)
                lFlags |= FLAG_SECONDARY_CUT
                lFlags |= FLAG_DRAG
              elsif (@DragMode == Wx::DRAG_COPY)
                lFlags |= FLAG_SECONDARY_COPY
                lFlags |= FLAG_DRAG
              else
                lFlags |= FLAG_DRAG_NONE
              end
            end
          end
          # Now compute the image ID
          lImageID = nil
          if (lShortcut.Metadata['icon'] != nil)
            # This image is unique to this Shortcut
            lImageID = [ lObjectID, lFlags ]
          else
            # Get the ID based on the Type
            lImageID = [ lShortcut.Type.pluginName, lFlags ]
          end
          # Now compute the image based on lFlags and the object ID
          lIdxImage = @ImageListManager.getTreeImageIndex(lImageID) do
            if (lFlags == 0)
              # Just return the original icon, without modifications
              if (lShortcut.Metadata['icon'] != nil)
                next lShortcut.Metadata['icon']
              else
                next lShortcut.Type.getIcon
              end
            else
              # We will apply some layers, so clone it first
              rBitmap = nil
              if (lShortcut.Metadata['icon'] != nil)
                rBitmap = lShortcut.Metadata['icon'].clone
              else
                rBitmap = lShortcut.Type.getIcon.clone
              end
              applyBitmapLayers(rBitmap, lFlags)
              next rBitmap
            end
          end
          set_item_image(iItemID, lIdxImage)
        end
      else
        puts "!!! Tree node #{iItemID} has unknown ID (#{lID}). It will be marked in the tree. Bug ?"
        set_item_text(iItemID, "!!! Unknown Data ID (Node ID: #{iItemID}, Data ID: #{lID}) !!!")
      end
      if ($PBS_DevDebug)
        # Add some debugging info
        set_item_text(iItemID, "#{get_item_text(iItemID)} (ID=#{lID}, ObjectID=#{lObjectID}, NodeID=#{iItemID})")
      end
    end

    # Remove a branch
    #
    # Parameters:
    # * *iNodeID* (_Integer_): The node ID, root of the branch to remove
    def removeTreeBranch(iNodeID)
      # First remove children branches
      children(iNodeID).each do |iChildID|
        removeTreeBranch(iChildID)
      end
      # Then remove the root registered info
      lID, lObjectID = get_item_data(iNodeID)
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
      delete(iNodeID)
    end

    # Insert a Tag in the main tree, and recursively all its children Tags and associated Shortcuts
    #
    # Parameters:
    # * *iParentID* (_Integer_): The node ID where the Tag will be inserted
    # * *iTag* (_Tag_): The Tag to insert
    def insertTreeBranch(iParentID, iTag)
      # Insert the new node
      lTagNodeID = append_item(iParentID, '')
      set_item_data(lTagNodeID, [ ID_TAG, iTag.getUniqueID ])
      @TagsToMainTree[iTag.getUniqueID] = lTagNodeID
      updateTreeNode(lTagNodeID)
      # Insert its children Tags also
      iTag.Children.each do |iChildTag|
        insertTreeBranch(lTagNodeID, iChildTag)
      end
      # Insert its associated Shortcuts
      @Controller.ShortcutsList.each do |iSC|
        if (iSC.Tags.has_key?(iTag))
          # Insert iSC as a child
          lSCNodeID = append_item(lTagNodeID, '')
          set_item_data(lSCNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
          updateTreeNode(lSCNodeID)
        end
      end
    end

    # Add information about a Shortcut into the tree
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut to add
    def addShortcutInfo(iSC)
      if (iSC.Tags.empty?)
        # Put at the root
        lNewNodeID = append_item(@RootID, '')
        set_item_data(lNewNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
        updateTreeNode(lNewNodeID)
      else
        iSC.Tags.each do |iTag, iNil|
          lTagID = @TagsToMainTree[iTag.getUniqueID]
          if (lTagID == nil)
            puts "!!! Shortcut #{iSC.Metadata['title']} is tagged with #{iTag.Name}, which does not exist in the known tags."
          else
            lNewNodeID = append_item(lTagID, '')
            set_item_data(lNewNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
            updateTreeNode(lNewNodeID)
          end
        end
      end
    end

    # Securely update the tree.
    # This method freezes the tree and ensures it becomes unfrozen.
    #
    # Parameters:
    # * *CodeBlock*: Code to execute while the tree is frozen
    def updateTree
      # First, freeze it for better performance during update
      freeze
      yield
      # Unfreeze it
      thaw
      # Redraw it
      refresh
    end

    # Delete an object (found in item_data) that is a direct child of a given Node ID
    #
    # Parameters:
    # * *iParentNodeID* (_Integer_): The parent node ID
    # * *iObject* (_Object_): The object to find
    def deleteObjectFromTree(iParentNodeID, iObject)
      # Find the node to delete
      lFound = false
      children(iParentNodeID).each do |iChildNodeID|
        lID, lObjectID = get_item_data(iChildNodeID)
        if (lObjectID == iObject.getUniqueID)
          # Found it
          delete(iChildNodeID)
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
    def fillTree
      updateTree do
        # Update it
        # Erase everything
        delete_all_items
        
        # Create root
        @RootID = add_root('PBS')
        set_item_data(@RootID, [ ID_TAG, @Controller.RootTag.getUniqueID ] )
        lIdxImage = @ImageListManager.getTreeImageIndex([ @Controller.RootTag.getUniqueID, 0 ]) do
          next ICON_ROOT_TAG
        end
        set_item_image(@RootID, lIdxImage)

        # Keep a correspondance of each Tag and its corresponding Tree ID
        # map< Tag, Integer >
        @TagsToMainTree = { @Controller.RootTag.getUniqueID => @RootID }
        # Insert each tag
        @Controller.RootTag.Children.each do |iTag|
          insertTreeBranch(@RootID, iTag)
        end
        # Insert each Shortcut that does not have any tag (the others were inserted by insertTreeBranch)
        @Controller.ShortcutsList.each do |iSC|
          if (iSC.Tags.empty?)
            lSCNodeID = append_item(@RootID, '')
            set_item_data(lSCNodeID, [ ID_SHORTCUT, iSC.getUniqueID ])
            updateTreeNode(lSCNodeID)
          end
        end
        expand(@RootID)
        if ($PBS_DevDebug)
          expand_all
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
      updateTree do
        lTagNodeID = @TagsToMainTree[iParentTag.getUniqueID]
        if (lTagNodeID == nil)
          puts '!!! The updated Tag was not inserted in the main tree. Bug ?'
        else
          # First remove Tags that are not part of the children anymore
          children(lTagNodeID).each do |iChildNodeID|
            lID, lObjectID = get_item_data(iChildNodeID)
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
                removeTreeBranch(iChildNodeID)
              end
            end
          end
          # Then add new Tags
          iParentTag.Children.each do |iChildTag|
            lChildID = @TagsToMainTree[iChildTag.getUniqueID]
            if (lChildID == nil)
              # We have to insert iChildTag, and all Shortcuts and children Tags associated to it
              insertTreeBranch(lTagNodeID, iChildTag)
            end
          end
        end
      end
      # If it was the root Tag, expand it (otherwise it can looks like a bug as root Tag does not have the + button.
      if (iParentTag.Parent == nil)
        expand(@RootID)
      end
    end

    # A Shortcut has just been added
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The added Shortcut
    def onShortcutAdd(iSC)
      # We update the tree accordingly
      updateTree do
        addShortcutInfo(iSC)
      end
    end

    # A Shortcut has just been deleted
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The deleted Shortcut
    def onShortcutDelete(iSC)
      # We update the tree accordingly
      updateTree do
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

    # An update has occured on a Tag's data
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag whose data was invalidated
    # * *iOldTagID* (<em>list<String></em>): The Tag ID before data modification
    # * *iOldName* (_String_): The previous name
    # * *iOldIcon* (<em>Wx::Bitmap</em>): The previous icon (can be nil)
    def onTagDataUpdate(iTag, iOldTagID, iOldName, iOldIcon)
      # We update the tree accordingly
      updateTree do
        # Retrieve the existing node
        lTagNodeID = @TagsToMainTree[iOldTagID]
        if (lTagNodeID == nil)
          puts "!!! Normally the tree should have registered Tag #{iOldTagID.join('/')}, but unable to retrieve it."
        else
          if (iOldName != iTag.Name)
            # Change its registration, as well as its children' registration as its ID has changed
            lIDSize = iOldTagID.size
            # The list of Tag IDs to delete
            # list< list< String > >
            lTagIDsToDelete = []
            # The map of Tag IDs to add
            # map< list< String >, Integer >
            lTagIDsToAdd = {}
            @TagsToMainTree.each do |iTagID, iNodeID|
              if (iTagID[0..lIDSize-1] == iOldTagID)
                lTagIDsToDelete << iTagID
                lNewTagID = iTagID.clone
                lNewTagID[lIDSize-1] = iTag.Name
                lTagIDsToAdd[lNewTagID] = iNodeID
                # Set its new ID in the tree
                set_item_data(iNodeID, [ ID_TAG, lNewTagID ])
              end
            end
            # Delete obsolete references
            lTagIDsToDelete.each do |iTagID|
              @TagsToMainTree.delete(iTagID)
            end
            # Add new references
            @TagsToMainTree.merge!(lTagIDsToAdd)
          end
          # Refresh it
          updateTreeNode(lTagNodeID)
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
      updateTree do
        # Just retrieve existing nodes and update them
        traverse do |iItemID|
          lID, lObjectID = get_item_data(iItemID)
          if (lObjectID == iOldSCID)
            # Store the new ID before updating the node
            set_item_data(iItemID, [ ID_SHORTCUT, iSC.getUniqueID ])
            # Update iItemID with the new info from iSC
            updateTreeNode(iItemID)
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
      updateTree do
        # First, delete any reference to iSC
        lSCID = iSC.getUniqueID
        lToBeDeleted = []
        traverse do |iItemID|
          lID, lObjectID = get_item_data(iItemID)
          if (lObjectID == lSCID)
            lToBeDeleted << iItemID
          end
        end
        lToBeDeleted.each do |iItemID|
          delete(iItemID)
        end
        # Then add iSC everywhere needed
        addShortcutInfo(iSC)
      end
    end

    # All Shortcuts/Tags data has been replaced
    def onReplaceAll
      fillTree
    end

    # Update all items affected by a multiple selection
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    def refreshSelectedItems(iSelection)
      # Update each item impacted by this selection
      updateTree do
        (iSelection.SelectedPrimaryShortcuts + iSelection.SelectedSecondaryShortcuts).each do |iSCInfo|
          iSCID, iParentTagID = iSCInfo
          # Find the node of the Tag
          lParentNodeID = @TagsToMainTree[iParentTagID]
          # Check each child, and update the one for our Shortcut
          children(lParentNodeID).each do |iChildNodeID|
            # If this child is for our SC, update it
            lID, lObjectID = get_item_data(iChildNodeID)
            if (lObjectID == iSCID)
              updateTreeNode(iChildNodeID)
            end
          end
        end
        (iSelection.SelectedPrimaryTags + iSelection.SelectedSecondaryTags).each do |iTagID|
          # Find the node of the Tag
          lTagNodeID = @TagsToMainTree[iTagID]
          updateTreeNode(lTagNodeID)
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

    # A selection is being moved using Drag'n'Drop
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    def onObjectsDragMove(iSelection)
      @DragSelection = iSelection
      @DragMode = Wx::DRAG_MOVE
      refreshSelectedItems(@DragSelection)
    end

    # A selection is being copied using Drag'n'Drop
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    def onObjectsDragCopy(iSelection)
      @DragSelection = iSelection
      @DragMode = Wx::DRAG_COPY
      refreshSelectedItems(@DragSelection)
    end

    # A selection is being invalidated using Drag'n'Drop
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    def onObjectsDragNone(iSelection)
      @DragSelection = iSelection
      @DragMode = Wx::DRAG_NONE
      refreshSelectedItems(@DragSelection)
    end

    # A Drag'n'Drop operation has ended
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    # * *iDragResult* (_Integer_): The result of the Drag'n'Drop operation
    def onObjectsDragEnd(iSelection, iDragResult)
      lOldDragSelection = @DragSelection
      @DragSelection = nil
      @DragMode = nil
      refreshSelectedItems(lOldDragSelection)
    end

    # Display some debugging info
    def onDevDebug
      puts '=== Correspondance between Tag IDs and Node IDs:'
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

      lParentNodeID = get_item_parent(iNodeID)
      lParentID, lParentTagID = get_item_data(lParentNodeID)
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

    # Return if the tree selection has effectively changed compared to the cache in @OldSelection
    #
    # Return:
    # * _Boolean_: Has tree selection changed ?
    def selectionChanged?
      rResult = false

      lSelection = selections
      if (lSelection != @OldSelection)
        @OldSelection = lSelection
        rResult = true
      end

      return rResult
    end

    # Is the Root Tag selected alone ?
    #
    # Return:
    # * _Boolean_: Is the Root Tag selected alone ?
    def isRootTagOnlySelected?
      lSelections = selections
      
      return ((lSelections.size == 1) and
              (lSelections[0] == @RootID))
    end

    # Get the currently selected object and its ID from the tree
    #
    # Return:
    # * _MultipleSelection_: The selection
    def getCurrentSelection
      rSelection = MultipleSelection.new(@Controller)

      # Get the selection from the main tree
      selections.each do |iSelectionID|
        lID, lObjectID = get_item_data(iSelectionID)
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

    # Get the Tag behind mouse coordinates from the main tree.
    # Uses a cache with @OldHoveredNodeID and @OldHoveredTag
    #
    # Parameters:
    # * *iMousePos* (<em>Wx::Point</em>): Mouse coordinates in the main tree's reference
    # Return:
    # * _Tag_: The Tag the mouse is hovering, or nil if none.
    def getHoveredTag(iMousePos)
      # Check which one we are hovering.
      lItemID, lFlags = hit_test(iMousePos)
      if (lItemID != @OldHoveredNodeID)
        # Item has changed: get the new hovered Tag if any
        @OldHoveredTag = nil
        if (lItemID != 0)
          # Check this is a Tag
          lID, lObjectID = get_item_data(lItemID)
          if (lID == ID_TAG)
            @OldHoveredTag = @Controller.findTag(lObjectID)
          end
        end
        # Remember the item being hovered, to not crawl under events
        @OldHoveredNodeID = lItemID
      end

      return @OldHoveredTag
    end

  end

end
