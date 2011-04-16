#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Dialog that resolves a conflict between 2 objects.
  # This is meant to be inherited to give objects specificities.
  class ResolveConflictDialog < Wx::Dialog

    # Those constants differentiate which panel has been chosen by the user
    CHOOSE_EXISTING = 0
    CHOOSE_CONFLICTING = 1

    # Create the buttons panel
    #
    # Parameters:
    # * *iParent* (_Window_): The parent window
    # Return:
    # * _Panel_: The panel containing controls
    def createButtonsPanel(iParent)
      rResult = Wx::Panel.new(iParent)

      # Create buttons
      lBMergeExisting = Wx::Button.new(rResult, Wx::ID_ANY, 'Merge using existing values')
      lBMergeConflicting = Wx::Button.new(rResult, Wx::ID_ANY, 'Merge using new values')
      lBKeep = Wx::Button.new(rResult, ID_KEEP, 'Keep both')
      lBCancel = Wx::Button.new(rResult, Wx::ID_CANCEL, 'Cancel')
      @CBApplyToAll = Wx::CheckBox.new(rResult, Wx::ID_ANY, 'Remember decision for future conflicts during this operation')

      # Put them in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      # First line of buttons: Merge existing, keep both and merge conflicting

      lFirstButtonsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lFirstButtonsSizer.add_item(lBMergeExisting,
        :flag => Wx::ALIGN_CENTRE,
        :proportion => 0
      )
      lFirstButtonsSizer.add_item([0,0], :proportion => 1)
      lFirstButtonsSizer.add_item(lBKeep,
        :flag => Wx::ALIGN_CENTRE,
        :proportion => 0
      )
      lFirstButtonsSizer.add_item([0,0], :proportion => 1)
      lFirstButtonsSizer.add_item(lBMergeConflicting,
        :flag => Wx::ALIGN_CENTRE,
        :proportion => 0
      )
      lMainSizer.add_item(lFirstButtonsSizer, :flag => Wx::GROW, :proportion => 0)

      # Second line of buttons: Remember and cancel
      lSecondButtonsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lSecondButtonsSizer.add_item([0,0], :proportion => 1)
      lSecondButtonsSizer.add_item(@CBApplyToAll,
        :flag => Wx::ALIGN_CENTRE,
        :proportion => 0
      )
      lSecondButtonsSizer.add_item([8,0], :proportion => 0)
      lSecondButtonsSizer.add_item(lBCancel,
        :flag => Wx::ALIGN_CENTRE,
        :proportion => 0
      )
      lMainSizer.add_item(lSecondButtonsSizer, :border => 8, :flag => Wx::GROW|Wx::TOP, :proportion => 0)
      rResult.sizer = lMainSizer

      # Set their events
      lBMergeExisting.evt_button(lBMergeExisting) do |iEvent|
        @MergeChoose = CHOOSE_EXISTING
        end_modal(ID_MERGE_EXISTING)
      end
      lBMergeConflicting.evt_button(lBMergeConflicting) do |iEvent|
        end_modal(ID_MERGE_CONFLICTING)
      end
      lBKeep.evt_button(lBKeep) do |iEvent|
        end_modal(ID_KEEP)
      end
      lBCancel.evt_button(lBCancel) do |iEvent|
        end_modal(Wx::ID_CANCEL)
      end

      return rResult
    end

    # Constructor
    #
    # Parameters:
    # * *iParentWindow* (<em>Wx::Window</em>): The parent window
    # * *iObjectTypeName* (_String_): Name of the objects we are comparing, that will be added as titles of their own region
    # * *iParameters* (...): The parameters to give the Dialog constructor
    def initialize(iParentWindow, iObjectTypeName, *iParameters)
      super(iParentWindow, *iParameters)

      # By default, the new data is the conflicting one
      @MergeChoose = CHOOSE_CONFLICTING

      # First create all the panels that will fit in this dialog
      # This is done calling the methods to be implemented by inherited class
      lSBExisting = Wx::StaticBox.new(self, Wx::ID_ANY, "Existing #{iObjectTypeName}")
      @ExistingObjectPanel = getExistingPanel
      # Set it read-only
      setChildrenReadOnly(@ExistingObjectPanel)
      lSBConflicting = Wx::StaticBox.new(self, Wx::ID_ANY, "Conflicting #{iObjectTypeName}")
      @ConflictingObjectPanel = getConflictingPanel
      lButtonsPanel = createButtonsPanel(self)
      lBTransfer = Wx::BitmapButton.new(self, Wx::ID_ANY, getGraphic('Transfer.png'))

      # Then put everything in place using sizers

      # Create the main sizer
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      # First sizer item is the group of 2 panels and the transfer button
      l2PanelsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lExistingSizer = Wx::StaticBoxSizer.new(lSBExisting, Wx::VERTICAL)
      lExistingSizer.add_item(@ExistingObjectPanel, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      l2PanelsSizer.add_item(lExistingSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      l2PanelsSizer.add_item(lBTransfer, :flag => Wx::ALIGN_CENTER, :proportion => 0)
      lConflictingSizer = Wx::StaticBoxSizer.new(lSBConflicting, Wx::VERTICAL)
      lConflictingSizer.add_item(@ConflictingObjectPanel, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      l2PanelsSizer.add_item(lConflictingSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lMainSizer.add_item(l2PanelsSizer, :flag => Wx::GROW|Wx::TOP|Wx::LEFT|Wx::RIGHT, :border => 8, :proportion => 1)
      # The second part of the main sizer is the panel containing the buttons
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::BOTTOM|Wx::LEFT|Wx::RIGHT, :border => 8, :proportion => 0)
      self.sizer = lMainSizer

      # Fit everything in place
      self.fit

      # Events
      lBTransfer.evt_button(lBTransfer) do |iEvent|
        # Transfer data from @ExistingObjectPanel to @ConflictingObjectPanel
        @ConflictingObjectPanel.setData(*@ExistingObjectPanel.getData)
      end

    end

    # Get the new data from the components
    #
    # Return:
    # * _String_: The name
    # * <em>Wx::Bitmap</em>: The icon (can be nil)
    def getData
      case @MergeChoose
      when CHOOSE_EXISTING
        return @ExistingObjectPanel.getData
      when CHOOSE_CONFLICTING
        return @ConflictingObjectPanel.getData
      else
        logBug "Unknown choice of conflicting dialog: #{@MergeChoose}."
        return @ConflictingObjectPanel.getData
      end
    end

    # Does the decision apply to future questions ?
    #
    # Return:
    # * _Boolean_: Does the decision apply to future questions ?
    def applyToAll?
      return @CBApplyToAll.value
    end

  end

end
