#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
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

    # The class defining the behaviour of the main tree for drop operations
    class SelectionDropTarget < Wx::DropTarget

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
        # The old cache key. Used to determine when the state has been changed during on_drag_over.
        @Cache_OldCacheKey = nil
        # The last displayed Tip Window
        # Wx::TipWindow
        @LastTipWindow = nil
        # The last change time. Used to determine if the user keeps hovering the same Tag, waiting for it to expand in order to drop on collapsed sub-Tags.
        # Time
        @LastChangeTime = Time.now
        # The last scroll time. Used to determine when it is needed to scroll a line while dragging near the borders.
        @LastScrollTime = Time.now
        super(@Data)
      end

      # Mouse is leaving the drop target.
      # This is also called when the drop ends on a vetoed area.
      def on_leave
        if (@LastTipWindow != nil)
          @LastTipWindow.destroy
          @LastTipWindow = nil
        end
      end

      # Called when the mouse is being dragged over the drop target. By default, this calls functions return the suggested return value def.
      # Use a cache of the last hovered item (otherwise it would be far too much CPU consuming as on_drag_over is always repeatedly called even if the mous does not move).
      # Expand Tag items on which the mouse stays hovering.
      #
      # Parameters:
      # * *iMouseX* (_Integer_): The x coordinate of the mouse.
      # * *iMouseY* (_Integer_): The y coordinate of the mouse.
      # * *iSuggestedResult* (_Integer_): Suggested value for return value. Determined by SHIFT or CONTROL key states.
      # Return:
      # * _Integer_: Returns the desired operation or Wx::DragNone. This is used for optical feedback from the side of the drop source, typically in form of changing the icon.
      def on_drag_over(iMouseX, iMouseY, iSuggestedResult)
        rResult = Wx::DRAG_NONE

        lHoveredTag = @PBSTreeCtrl.getHoveredTag(Wx::Point.new(iMouseX, iMouseY))
        if (lHoveredTag != nil)
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
              logBug "Unknown suggested result: #{iSuggestedResult}"
            end
            lPasteOK, lErrors = isPasteAuthorized?(
              @Controller,
              lSelection,
              lCopyMode,
              @Controller.DragSelection,
              nil
            )
            if (lPasteOK)
              @Cache_LastHoveredTags[lCacheKey] = [ iSuggestedResult, nil ]
            else
              @Cache_LastHoveredTags[lCacheKey] = [ Wx::DRAG_NONE, lErrors ]
            end
          end
          rResult, lErrors = @Cache_LastHoveredTags[lCacheKey]
          if (@Cache_OldCacheKey != lCacheKey)
            # Here we have changed states. Consider displaying the reasons for error.
            if (@LastTipWindow != nil)
              @LastTipWindow.destroy
              @LastTipWindow = nil
            end
            @Cache_OldCacheKey = lCacheKey
            if (lErrors != nil)
              # Display the errors in a hint for explanations
              @LastTipWindow = Wx::TipWindow.new(@PBSTreeCtrl, lErrors.join("\n"))
              @LastTipWindow.show
            end
            @LastChangeTime = Time.now
          else
            # Here, we might want to expand lHoveredTag in @PBSTreeCtrl to show the content after some delay.
            # 1 second is ok
            if (Time.now - @LastChangeTime > 1)
              # Expand the Tag if not already the case
              lItemID, lFlags = @PBSTreeCtrl.hit_test(Wx::Point.new(iMouseX, iMouseY))
              if (!@PBSTreeCtrl.is_expanded(lItemID))
                @PBSTreeCtrl.expand(lItemID)
              end
            end
          end
        end
        # Here we scroll vertically if the mouse is close to the borders
        if (Time.now - @LastScrollTime > 0.2)
          if (iMouseY < @PBSTreeCtrl.client_rect.y + 8)
            # Scroll up
            lTopItemID = @PBSTreeCtrl.get_prev_visible(@PBSTreeCtrl.first_visible_item)
            if (lTopItemID != 0)
              @PBSTreeCtrl.scroll_to(lTopItemID)
              @LastScrollTime = Time.now
            end
          elsif (iMouseY > @PBSTreeCtrl.client_rect.y + @PBSTreeCtrl.client_rect.height - 8)
            # Scroll down
            lTopItemID = @PBSTreeCtrl.get_next_visible(@PBSTreeCtrl.first_visible_item)
            if (lTopItemID != 0)
              @PBSTreeCtrl.scroll_to(lTopItemID)
              @LastScrollTime = Time.now
            end
          end
        end

        return rResult
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
        lCopyType, lCopyID, lSerializedSelection = @Data.getData
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
          logBug "Unknown suggested result: #{iSuggestedResult}"
        end
        lPasteOK, lErrors = isPasteAuthorized?(
          @Controller,
          lSelection,
          lCopyMode,
          @Controller.DragSelection,
          lSerializedSelection
        )
        if (lPasteOK)
          @Controller.undoableOperation("Paste #{lSerializedSelection.getDescription} in #{lSelectedTag.Name}") do
            lSerializedSelection.createSerializedTagsShortcuts(@Controller, lSelectedTag, @Controller.DragSelection)
          end
          return iSuggestedResult
        else
          logErr "Can't drop because of #{lErrors.size} errors:\n#{lErrors.join("\n")}"
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

    # This class implements a minimalistic frame that can replace TipWindow.
    # It notifies its parent window that it has been destroyed when it occurs with the time out.
    # TODO (WxRuby): Make ToolTip work on TreeCtrl component with evt_tree_item_gettooltip
    # TODO (WxRuby): Implement ToolTip.set_delay
    # TODO (WxRuby): Implement TreeEvent.set_tool_tip
    class HintFrame < Wx::Frame

      # Get standard Hint colors
      HINT_TEXT_COLOR = Wx::SystemSettings::get_colour(Wx::SYS_COLOUR_INFOTEXT)
      HINT_BACK_COLOR = Wx::SystemSettings::get_colour(Wx::SYS_COLOUR_INFOBK)

      # Border in pixels around the label
      BORDER_SIZE = 4

      # Constructor
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): Parent window
      # * *iToolTip* (_String_): The tool tip to display
      # * *iPosition* (<em>Wx::Point</em>): Position to give to the window
      # * *iTimeout* (_Integer_): Timeout in milliseconds before destruction
      # * *iSafeTimersManager* (_SafeTimersManager_): The safe timers manager that will be used to secure the timeout timer
      def initialize(iParent, iToolTip, iPosition, iTimeout, iSafeTimersManager)
        super(iParent, Wx::ID_ANY, iToolTip,
          :style => Wx::FRAME_TOOL_WINDOW|Wx::FRAME_NO_TASKBAR|Wx::FRAME_FLOAT_ON_PARENT,
          :pos => iParent.client_to_screen(iPosition)
        )
        set_background_colour(HINT_BACK_COLOR)
        set_foreground_colour(HINT_TEXT_COLOR)

        # Compute the size based on the tool tip
        lWidth, lHeight, lDescent, lExternalLeading = get_text_extent(iToolTip)

        # Create the label
        lSTToolTip = Wx::StaticText.new(self, Wx::ID_ANY, iToolTip)
        # Center it in the frame
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item([0,BORDER_SIZE/2], :proportion => 1)
        lMainSizer.add_item(lSTToolTip, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item([0,BORDER_SIZE/2], :proportion => 1)
        self.sizer = lMainSizer
        self.fit
        self.size = Wx::Size.new(lWidth + BORDER_SIZE, lHeight + BORDER_SIZE)

        # Kill after timeout
        safeTimerAfter(iSafeTimersManager, iTimeout) do
          if (iParent.LastToolTip == self)
            iParent.notifyHintKilled(self)
            destroy
          end
        end
      end

    end

    # Set the Root Tag to display. this can be any Tag, or the real root Tag
    #
    # Parameters:
    # * *iRootTag* (_Tag_): The new Root Tag to consider in the display
    def setRootTag(iRootTag)
      # Don't reset everything if nothing changed
      if (@RootTag != iRootTag)
        @RootTag = iRootTag
        # Know if we are dealing with the real Root Tag (behaviour changes on the real one)
        @RealRootTag = (@Controller.RootTag == iRootTag)
        updateTree do
          # Update it
          # Erase everything
          delete_all_items
          # Keep a correspondance of each Tag and its corresponding Tree ID
          # map< Tag, Integer >
          @TagsToMainTree = {}
          # Insert everything
          insertTreeBranch(nil, @RootTag)
          # Expand
          if ($PBS_DevDebug)
            expand_all
          else
            expand(root_item)
          end
        end
      end
    end

    # The last created tool tip, useful for timers of HintFrames that have to check if the window still exists before destroying.
    #   HintFrame
    attr_reader :LastToolTip

    # Notify that the hint previously created is destroyed
    #
    # Parameters:
    # * *iHintWindow* (_HintFrame_): The window being killed
    def notifyHintKilled(iHintWindow)
      @LastToolTip = nil
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
        :style => Wx::TR_EDIT_LABELS|Wx::TR_HAS_BUTTONS|Wx::TR_MULTIPLE|Wx::TR_EXTENDED
      )

      # The safe Timers manager for this tree
      @TimersManager = RUtilAnts::GUI::SafeTimersManager.new

      # The Root Tag to be displayed
      # Tag
      @RootTag = nil
      # Is the Root Tag to be displayed the real Root Tag from the Controller ?
      # Boolean
      @RealRootTag = false

      # TODO (WxRuby): Bug correction
      # Register this Event as otherwise moving the mouse over the TreeCtrl component generates tons of warnings. Bug ?
      Wx::EvtHandler::EVENT_TYPE_CLASS_MAP[10000] = Wx::Event
      # TODO (WxRuby): Bug correction
      # Register this Event as otherwise destroy ToolTips during drag generate tons of warnings. Bug ?
      Wx::EvtHandler::EVENT_TYPE_CLASS_MAP[10131] = Wx::Event

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
      # The Tags references to tree nodes
      # map< Tag, Integer >
      @TagsToMainTree = nil
      # The drag image
      # Wx::DragImage
      @DragImage = nil
      # The context menu
      # Wx::Menu
      @ContextMenu = nil
      # The last item ID that was under the mouse.
      # This is used to detect when the mouse changes items for tool tips.
      # It stores also the time stamp to detect in timers if we didn't change items and come back.
      # [ Integer, Time ]
      @LastItemUnderMouse = nil
      # Last tool tip created
      # HintFrame
      @LastToolTip = nil
      # Create the image list for the tree
      lTreeImageList = Wx::ImageList.new(16, 16)
      set_image_list(lTreeImageList)
      # Make this image list driven by a manager
      @ImageListManager = RUtilAnts::GUI::ImageListManager.new(lTreeImageList, 16, 16)
      # Accept incoming drops of things
      # Keep a reference to the DropTarget, as otherwise it results in a core dump when dragging over the tree (another way to avoid this reference is to use drop_target= instead of set_drop_target). Bug ?
      self.drop_target = SelectionDropTarget.new(@Controller, self)

      # All events

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
            @Controller.executeCommand(Wx::ID_DELETE, {
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
        if ((iEvent.item == root_item) and
            (@RealRootTag))
          iEvent.veto
        else
          # Remove the 'Del' key from accelerators
          @Controller.blockAccelerator([ 0, Wx::K_DELETE ] )
          iEvent.skip
        end
      end
      evt_tree_end_label_edit(self) do |iEvent|
        @Controller.unblockAccelerator([ 0, Wx::K_DELETE ] )
        # First, retrieve who we are editing (we are sure it can't be the root)
        lID, lObject, lKey = get_item_data(iEvent.item)
        lNewName = iEvent.label
        if (lNewName.strip != '')
          case lID
          when ID_TAG
            if (lNewName != lObject.Name)
              @Controller.undoableOperation("Edit Tag's name #{lObject.Name}") do
                @Controller.updateTag(lObject, lNewName, lObject.Icon, lObject.Children)
              end
            end
          when ID_SHORTCUT
            if (lNewName != lObject.Metadata['title'])
              @Controller.undoableOperation("Edit Shortcut's name #{lObject.Metadata['title']}") do
                lNewMetadata = lObject.Metadata.clone
                lNewMetadata['title'] = lNewName
                @Controller.updateShortcut(lObject, lObject.Content, lNewMetadata, lObject.Tags)
              end
            end
          else
            logBug "We are editing an item of unknown ID: #{lID}."
          end
        end
        # We always veto the event, as the label was forcefully modified by notifiers during this event
        iEvent.veto
      end

      # Giving tool tips about items
      evt_motion do |iEvent|
        lMousePosition = Wx::Point.new(iEvent.x, iEvent.y)
        lItemID, lFlags = hit_test(lMousePosition)
        if ((@LastItemUnderMouse == nil) or
            (lItemID != @LastItemUnderMouse[0]))
          notifyMouseChangedItems(lItemID, lMousePosition)
        end
        iEvent.skip
      end
      evt_enter_window do |iEvent|
        lMousePosition = Wx::Point.new(iEvent.x, iEvent.y)
        notifyMouseChangedItems(0, lMousePosition)
      end
      evt_leave_window do |iEvent|
        lMousePosition = Wx::Point.new(iEvent.x, iEvent.y)
        notifyMouseChangedItems(0, lMousePosition)
      end

      # Run on double-click
      evt_tree_item_activated(self) do |ioEvent|
        lItemID = ioEvent.item
        if (lItemID != 0)
          # Get the item data
          lID, lObject, lKey = get_item_data(lItemID)
          if (lID == ID_SHORTCUT)
            # Run the corresponding Shortcut
            lObject.run
          end
        end
        ioEvent.skip
      end

      # Prevent Root collapsing
      evt_tree_item_collapsing(self) do |ioEvent|
        lItemID = ioEvent.item
        if (lItemID == root_item)
          ioEvent.veto
        end
      end

    end

    # Compare 2 items for sort
    #
    # Parameters:
    # * *iItemID1* (_Integer_): First item ID
    # * *iItemID2* (_Integer_): Second item ID
    # Return:
    # * _Integer: (First item - Second item)
    def on_compare_items(iItemID1, iItemID2)
      rCompare = 0

      lID1, lObject1, lKey1 = get_item_data(iItemID1)
      lID2, lObject2, lKey2 = get_item_data(iItemID2)
      if ((lID1 == ID_TAG) and
          (lID2 == ID_SHORTCUT))
        rCompare = -1
      elsif ((lID1 == ID_SHORTCUT) and
             (lID2 == ID_TAG))
        rCompare = 1
      else
        rCompare = (lKey1 <=> lKey2)
      end

      return rCompare
    end

    # Notify that the mouse is not on the same item anymore
    #
    # Parameters:
    # * *iItemID* (_Integer_): The new item ID the mouse is hovering (can be 0)
    # * *iMousePosition* (<em>Wx::Point</em>): The mouse position
    def notifyMouseChangedItems(iItemID, iMousePosition)
      # We have changed items: destroy previous tool tip if present
      if (@LastToolTip != nil)
        @LastToolTip.destroy
        @LastToolTip = nil
      end
      @LastItemUnderMouse = [ iItemID, Time.now ]
      lOurTimeStamp = @LastItemUnderMouse.clone
      # Set the hint to come after 1.5s
      safeTimerAfter(@TimersManager, 1500) do
        # Check if we are still on the same item
        if (lOurTimeStamp == @LastItemUnderMouse)
          # Time to display a hint
          displayHint(iItemID, iMousePosition)
        end
      end
    end

    # Display a Hint
    #
    # Parameters:
    # * *iItemID* (_Integer_): The item ID for which we display the hint
    # * *iMousePosition* (<em>Wx::Point</em>): The mouse position to display the hint
    def displayHint(iItemID, iMousePosition)
      lToolTip = nil
      if (iItemID != 0)
        lID, lObject, lKey = get_item_data(iItemID)
        case lID
        when ID_TAG
          lToolTip = lObject.Name
        when ID_SHORTCUT
          lToolTip = lObject.getContentSummary
        else
          logBug "Asking tool tip for an item of unknwown ID: #{lID}. Ignoring it."
        end
      end
      if (@LastToolTip != nil)
        @LastToolTip.destroy
        @LastToolTip = nil
      end
      if (lToolTip != nil)
        @LastToolTip = HintFrame.new(self, lToolTip, iMousePosition, 2000, @TimersManager)
        @LastToolTip.show
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

    # Set one of tree's node attributes to fit its associated data (Tag or Shortcut).
    # Only this method knows how to display tree nodes.
    #
    # Parameters:
    # * *iItemID* (_Integer_): The item of the main tree that we want to update
    def updateTreeNode(iItemID)
      lItemData = get_item_data(iItemID)
      lID, lObject, lKey = lItemData
      lItemText = ''
      case lID
      when ID_TAG
        # If this is the real Root Tag, there is some special display
        if (lObject == @Controller.RootTag)
          # Set the text
          lItemText = 'PBS'
          # Now compute the image ID
          lIdxImage = @ImageListManager.getImageIndex([ @Controller.RootTag, 0 ]) do
            next getGraphic('Icon16.png')
          end
          set_item_image(iItemID, lIdxImage)
        else
          # Set the text
          lItemText = lObject.Name
          # Compute the masks to put on the icon
          # list< Wx::Bitmap >
          lMasks = []
          # Check the Copy/Cut markers
          if (@CopySelection != nil)
            if (@CopySelection.isTagPrimary?(lObject))
              if (@CopyMode == Wx::ID_CUT)
                lMasks << getGraphic('MiniCut.png')
              else
                lMasks << getGraphic('MiniCopy.png')
              end
            end
            if (@CopySelection.isTagSecondary?(lObject))
              if (@CopyMode == Wx::ID_CUT)
                lMasks << getGraphic('MicroCut.png')
              else
                lMasks << getGraphic('MicroCopy.png')
              end
            end
          end
          if (@DragSelection != nil)
            if (@DragSelection.isTagPrimary?(lObject))
              if (@DragMode == Wx::DRAG_MOVE)
                lMasks << getGraphic('MiniCut.png')
                lMasks << getGraphic('DragNDrop.png')
              elsif (@DragMode == Wx::DRAG_COPY)
                lMasks << getGraphic('MiniCopy.png')
                lMasks << getGraphic('DragNDrop.png')
              else
                lMasks << getGraphic('DragNDropCancel.png')
              end
            end
            if (@DragSelection.isTagSecondary?(lObject))
              if (@DragMode == Wx::DRAG_MOVE)
                lMasks << getGraphic('MicroCut.png')
                lMasks << getGraphic('DragNDrop.png')
              elsif (@DragMode == Wx::DRAG_COPY)
                lMasks << getGraphic('MicroCopy.png')
                lMasks << getGraphic('DragNDrop.png')
              else
                lMasks << getGraphic('DragNDropCancel.png')
              end
            end
          end
          # Now compute the image ID
          lImageID = nil
          if (lObject.Icon != nil)
            # This image is unique to this Shortcut
            lImageID = [ lObject, lMasks ]
          else
            # This is the ID for Tags having no icon.
            lImageID = [ nil, lMasks ]
          end
          # Now compute the image based on lFlags and the object ID
          lIdxImage = @ImageListManager.getImageIndex(lImageID) do
            if (lMasks.empty?)
              # Just return the original icon, without modifications
              next @Controller.getTagIcon(lObject)
            else
              # We will apply some layers, so clone the original bitmap
              rBitmap = @Controller.getTagIcon(lObject).clone
              applyBitmapLayers(rBitmap, lMasks)
              next rBitmap
            end
          end
          set_item_image(iItemID, lIdxImage)
        end
      when ID_SHORTCUT
        # Retrieve the Shortcut
        lItemText = lObject.Metadata['title']
        if (lItemText == nil)
          lItemText = '-- Unknown title --'
        end
        # Compute the masks to put on the icon
        # list< Wx::Bitmap >
        lMasks = []
        # Check the Copy/Cut markers
        if (@CopySelection != nil)
          lParentTag = getParentTag(iItemID)
          if (@CopySelection.isShortcutPrimary?(lObject, lParentTag))
            if (@CopyMode == Wx::ID_CUT)
              lMasks << getGraphic('MiniCut.png')
            else
              lMasks << getGraphic('MiniCopy.png')
            end
          end
          if (@CopySelection.isShortcutSecondary?(lObject, lParentTag))
            if (@CopyMode == Wx::ID_CUT)
              lMasks << getGraphic('MicroCut.png')
            else
              lMasks << getGraphic('MicroCopy.png')
            end
          end
        end
        if (@DragSelection != nil)
          lParentTag = getParentTag(iItemID)
          if (@DragSelection.isShortcutPrimary?(lObject, lParentTag))
            if (@DragMode == Wx::DRAG_MOVE)
              lMasks << getGraphic('MiniCut.png')
              lMasks << getGraphic('DragNDrop.png')
            elsif (@DragMode == Wx::DRAG_COPY)
              lMasks << getGraphic('MiniCopy.png')
              lMasks << getGraphic('DragNDrop.png')
            else
              lMasks << getGraphic('DragNDropCancel.png')
            end
          end
          if (@DragSelection.isShortcutSecondary?(lObject, lParentTag))
            if (@DragMode == Wx::DRAG_MOVE)
              lMasks << getGraphic('MicroCut.png')
              lMasks << getGraphic('DragNDrop.png')
            elsif (@DragMode == Wx::DRAG_COPY)
              lMasks << getGraphic('MicroCopy.png')
              lMasks << getGraphic('DragNDrop.png')
            else
              lMasks << getGraphic('DragNDropCancel.png')
            end
          end
        end
        # Now compute the image ID
        lImageID = nil
        if (lObject.Metadata['icon'] != nil)
          # This image is unique to this Shortcut
          lImageID = [ lObject, lMasks ]
        else
          # Get the ID based on the Type
          lImageID = [ lObject.Type.pluginDescription[:PluginName], lMasks ]
        end
        # Now compute the image based on lFlags and the object ID
        lIdxImage = @ImageListManager.getImageIndex(lImageID) do
          if (lMasks.empty?)
            # Just return the original icon, without modifications
            next @Controller.getShortcutIcon(lObject)
          else
            # We will apply some layers, so clone it first
            rBitmap = @Controller.getShortcutIcon(lObject).clone
            applyBitmapLayers(rBitmap, lMasks)
            next rBitmap
          end
        end
        set_item_image(iItemID, lIdxImage)
      else
        logBug "Tree node #{iItemID} has unknown ID (#{lID}). It will be marked in the tree."
        lItemText = "!!! Unknown Data ID (Node ID: #{iItemID}, Data ID: #{lID}) !!!"
      end
      if ($PBS_DevDebug)
        # Add some debugging info
        lItemText = "#{lItemText} (NodeID=#{iItemID}, ID=#{lID}, Object=#{lObject})"
      end
      if (get_item_text(iItemID) != lItemText)
        set_item_text(iItemID, lItemText)
        # Modify also the data associated
        lItemData[2] = convertAccentsString(lItemText.upcase)
        # Now that this item has changed, mark its parent to be sorted for the next end of transaction
        lParentItemID = get_item_parent(iItemID)
        if (lParentItemID != 0)
          if (is_frozen)
            @ItemsToSort[lParentItemID] = nil
          else
            sort_children(lParentItemID)
          end
        end
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
      lID, lObject, lKey = get_item_data(iNodeID)
      case lID
      when ID_TAG
        # Remove a Tag reference
        lNodeID = @TagsToMainTree.delete(lObject)
        if (lNodeID != iNodeID)
          logBug "We are removing node ID #{iNodeID}, referenced for Tag #{lObject.Name}, but this Tag ID was registered for another node of ID #{lNodeID}."
        end
      when ID_SHORTCUT
        # Remove a Shortcut reference
        # Nothing to do
      else
        logBug "We are trying to remove a tree node (ID = #{iNodeID}) that is not registered as a Tag not a Shortcut (ID = #{lID})."
      end
      # And remove the node itself
      delete(iNodeID)
    end

    # Insert a Tag in the main tree, and recursively all its children Tags and associated Shortcuts
    #
    # Parameters:
    # * *iParentID* (_Integer_): The node ID where the Tag will be inserted (can be nil for the first node to insert)
    # * *iTag* (_Tag_): The Tag to insert
    def insertTreeBranch(iParentID, iTag)
      # Insert the new node
      lTagNodeID = nil
      if (iParentID == nil)
        lTagNodeID = add_root('PBS')
      else
        lTagNodeID = append_item(iParentID, '')
      end
      set_item_data(lTagNodeID, [ ID_TAG, iTag, nil ])
      @TagsToMainTree[iTag] = lTagNodeID
      updateTreeNode(lTagNodeID)
      # Insert its children Tags also
      iTag.Children.each do |iChildTag|
        insertTreeBranch(lTagNodeID, iChildTag)
      end
      # Insert its associated Shortcuts
      if ((iParentID == nil) and
          (@RealRootTag))
        # We insert Shortcuts having no Tag
        @Controller.ShortcutsList.each do |iSC|
          if (iSC.Tags.empty?)
            # Insert iSC as a child
            lSCNodeID = append_item(lTagNodeID, '')
            set_item_data(lSCNodeID, [ ID_SHORTCUT, iSC, nil ])
            updateTreeNode(lSCNodeID)
          end
        end
      else
        @Controller.ShortcutsList.each do |iSC|
          if (iSC.Tags.has_key?(iTag))
            # Insert iSC as a child
            lSCNodeID = append_item(lTagNodeID, '')
            set_item_data(lSCNodeID, [ ID_SHORTCUT, iSC, nil ])
            updateTreeNode(lSCNodeID)
          end
        end
      end
    end

    # Add information about a Shortcut into the tree
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut to add
    def addShortcutInfo(iSC)
      if (iSC.Tags.empty?)
        # Put at the root if it is displayed
        if (@RealRootTag)
          lNewNodeID = append_item(root_item, '')
          set_item_data(lNewNodeID, [ ID_SHORTCUT, iSC, nil ])
          updateTreeNode(lNewNodeID)
        end
      else
        iSC.Tags.each do |iTag, iNil|
          lTagID = @TagsToMainTree[iTag]
          # It is possible that iTag is not present, in the following cases:
          # * Pasting a Shortcut whose Tag was deleted in the meantime, OR
          # * The Tag is not displayed
          if (lTagID != nil)
            lNewNodeID = append_item(lTagID, '')
            set_item_data(lNewNodeID, [ ID_SHORTCUT, iSC, nil ])
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
      onTransactionBegin
      begin
        yield
      rescue Exception
        # Unfreeze it
        thaw
        # Redraw it
        refresh
        # Propagate the exception
        raise
      end
      onTransactionEnd
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
        lID, lObject, lKey = get_item_data(iChildNodeID)
        if (lObject == iObject)
          # Found it
          delete(iChildNodeID)
          lFound = true
          break
        end
      end
      # Just a little Bug detection mechanism ... never know.
      if (!lFound)
        logBug "Object #{iObject} should have been inserted under node #{iParentNodeID}). However no trace of this object in the children nodes."
      end
    end

    # Notify that a transaction is beginning
    def onTransactionBegin
      freeze
      # the set of items that will need to be sorted
      # map< Integer, nil >
      @ItemsToSort = {}
    end

    # Notify that a transaction is ending
    def onTransactionEnd
      @ItemsToSort.each do |iItemID, iNil|
        sort_children(iItemID)
      end
      # Check if we need to expand the Root item.
      # This needs to be done here because of a WxRuby bug preventing from doing it when there is no child.
      # TODO (WxRuby): Make expand work event if there are no children
      if ((!is_expanded(root_item)) and
          (get_children_count(root_item) > 0))
        expand(root_item)
      end
      thaw
      refresh
    end

    # Notify that a given Tag's children list has changed
    #
    # Parameters:
    # * *iParentTag* (_Tag_): The Tag whose children list has changed
    # * *iOldChildrenList* (<em>list<Tag></em>): The old children list
    def onTagChildrenUpdate(iParentTag, iOldChildrenList)
      # We update the tree accordingly
      lTagNodeID = @TagsToMainTree[iParentTag]
      # It can be normal that the Tag is not present
      if (lTagNodeID != nil)
        # First remove Tags that are not part of the children anymore
        children(lTagNodeID).each do |iChildNodeID|
          lID, lObject, lKey = get_item_data(iChildNodeID)
          if (lID == ID_TAG)
            # Check if lObjectID is part of the children of iParentTag
            lFound = false
            iParentTag.Children.each do |iChildTag|
              if (iChildTag == lObject)
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
          lChildID = @TagsToMainTree[iChildTag]
          if (lChildID == nil)
            # We have to insert iChildTag, and all Shortcuts and children Tags associated to it
            insertTreeBranch(lTagNodeID, iChildTag)
          end
        end
      end
    end

    # A Shortcut has just been added
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The added Shortcut
    def onShortcutCreate(iSC)
      # We update the tree accordingly
      addShortcutInfo(iSC)
    end

    # A Shortcut has just been deleted
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The deleted Shortcut
    def onShortcutDelete(iSC)
      # We update the tree accordingly
      if (iSC.Tags.empty?)
        # Delete it from root if the Root is displayed
        if (@RealRootTag)
          deleteObjectFromTree(root_item, iSC)
        end
      else
        # For each Tag this Shortcut was belonging to, we will delete its node
        iSC.Tags.each do |iTag, iNil|
          lTagNodeID = @TagsToMainTree[iTag]
          # It is possible that this Tag is not displayed
          if (lTagNodeID != nil)
            deleteObjectFromTree(lTagNodeID, iSC)
          end
        end
      end
    end

    # An update has occured on a Tag's data
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag whose data was invalidated
    # * *iOldName* (_String_): The previous name
    # * *iOldIcon* (<em>Wx::Bitmap</em>): The previous icon (can be nil)
    def onTagDataUpdate(iTag, iOldName, iOldIcon)
      # We update the tree accordingly
      # Retrieve the existing node
      lTagNodeID = @TagsToMainTree[iTag]
      # It is possible that it does not exist
      if (lTagNodeID != nil)
        # Refresh it
        updateTreeNode(lTagNodeID)
      end
    end

    # An update has occured on a Shortcut's data
    #
    # Parameters:
    # * *iSC* (_Shortcut_): The Shortcut whose data was invalidated
    # * *iOldContent* (_Object_): The previous content, or nil if it was not modified
    # * *iOldMetadata* (_Object_): The previous metadata, or nil if it was not modified
    def onShortcutDataUpdate(iSC, iOldContent, iOldMetadata)
      # We update the tree accordingly
      # Just retrieve existing nodes and update them
      traverse do |iItemID|
        lID, lObject, lKey = get_item_data(iItemID)
        if (lObject == iSC)
          # Store the new ID before updating the node
          set_item_data(iItemID, [ ID_SHORTCUT, iSC, nil ])
          # Update iItemID with the new info from iSC
          updateTreeNode(iItemID)
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
      # First, delete any reference to iSC
      lToBeDeleted = []
      traverse do |iItemID|
        lID, lObject, lKey = get_item_data(iItemID)
        if (lObject == iSC)
          lToBeDeleted << iItemID
        end
      end
      lToBeDeleted.each do |iItemID|
        delete(iItemID)
      end
      # Then add iSC everywhere needed
      addShortcutInfo(iSC)
    end

    # Update all items affected by a multiple selection
    #
    # Parameters:
    # * *iSelection* (_MultipleSelection_): The selection
    def refreshSelectedItems(iSelection)
      # Update each item impacted by this selection
      (iSelection.SelectedPrimaryShortcuts + iSelection.SelectedSecondaryShortcuts).each do |iSCInfo|
        iSC, iParentTag = iSCInfo
        # Find the node of the Tag (it is possible that it does not exist anymore in case of deleted cut item)
        lParentNodeID = @TagsToMainTree[iParentTag]
        if (lParentNodeID != nil)
          # Check each child, and update the one for our Shortcut
          children(lParentNodeID).each do |iChildNodeID|
            # If this child is for our SC, update it
            lID, lObject, lKey = get_item_data(iChildNodeID)
            if (lObject == iSC)
              updateTreeNode(iChildNodeID)
            end
          end
        end
      end
      (iSelection.SelectedPrimaryTags + iSelection.SelectedSecondaryTags).each do |iTag|
        # Find the node of the Tag
        lTagNodeID = @TagsToMainTree[iTag]
        updateTreeNode(lTagNodeID)
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
      logDebug '=== Correspondance between Tag IDs and Node IDs:'
      @TagsToMainTree.each do |iTag, iNodeID|
        logDebug "#{iTag.Name} => #{iNodeID}"
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
      lParentID, rParentTag, lKey = get_item_data(lParentNodeID)
      if (lParentID != ID_TAG)
        logBug "Parent node #{lParentNodeID} should be flagged as a Tag, but is flagged as #{lParentID}."
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
      
      return ((@RealRootTag) and
              (lSelections.size == 1) and
              (lSelections[0] == root_item))
    end

    # Get the currently selected object and its ID from the tree
    #
    # Return:
    # * _MultipleSelection_: The selection
    def getCurrentSelection
      rSelection = MultipleSelection.new(@Controller)

      # Get the selection from the main tree
      selections.each do |iSelectionID|
        lID, lObject, lKey = get_item_data(iSelectionID)
        case lID
        when ID_TAG
          rSelection.selectTag(lObject)
        when ID_SHORTCUT
          # Get the parent Tag
          lParentTag = getParentTag(iSelectionID)
          rSelection.selectShortcut(lObject, lParentTag)
        else
          logBug "One of the selected items has an unknown ID (#{lID})."
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
          lID, lObject, lKey = get_item_data(lItemID)
          if (@TagsToMainTree[lObject] != nil)
            @OldHoveredTag = lObject
          end
        end
        # Remember the item being hovered, to not crawl under events
        @OldHoveredNodeID = lItemID
      end

      return @OldHoveredTag
    end

    # Stop remaining timers and wait for them to be safely removed
    def killTimers
      @TimersManager.killTimers
    end

  end

end
