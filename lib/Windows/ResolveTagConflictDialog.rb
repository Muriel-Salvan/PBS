#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/TagMetadataPanel.rb'

module PBS

  # Dialog that resolves conflict on a Tag
  class ResolveTagConflictDialog < Wx::Dialog

    # Create the buttons panel
    #
    # Parameters:
    # * *iParent* (_Window_): The parent window
    # Return:
    # * _Panel_: The panel containing controls
    def createButtonsPanel(iParent)
      rResult = Wx::Panel.new(iParent)

      # Create buttons
      lBMerge = Wx::Button.new(rResult, ID_MERGE, 'Merge using above values')
      lBKeep = Wx::Button.new(rResult, ID_KEEP, 'Keep both')
      lBCancel = Wx::Button.new(rResult, Wx::ID_CANCEL, 'Cancel')
      lCBApplyToAll = Wx::CheckBox.new(rResult, -1, 'Apply to remaining conflicts')

      # Put them in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lMainSizer.add_item(lBMerge, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item(lBKeep, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item([0,0], :proportion => 1)
      lMainSizer.add_item(lBCancel, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item(lCBApplyToAll, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      rResult.sizer = lMainSizer

      # Set their events
      lBMerge.evt_button(lBMerge) do |iEvent|
        end_modal(ID_MERGE)
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
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iTag* (_Tag_): The existing Tag
    # * *iName* (_String_): Tag name getting into conflict
    # * *iIcon* (<em>Wx::Bitmap</em>): Icon getting into conflict
    def initialize(iParent, iTag, iName, iIcon)
      super(iParent,
        :title => 'Resolve conflicts between 2 Tags',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # First create all the panels that will fit in this dialog
      @ExistingMetadataPanel = TagMetadataPanel.new(self, iTag.Name, iTag.Icon)
      # Make it read-only
      @ExistingMetadataPanel.enable(false)
      @ConflictingMetadataPanel = TagMetadataPanel.new(self, iName, iIcon)
      lButtonsPanel = createButtonsPanel(self)

      # Then put everything in place using sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)

      # First sizer item is the group of 2 content/metadata panels
      l2PanelsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      l2PanelsSizer.add_item(@ExistingMetadataPanel, :flag => Wx::GROW, :proportion => 1)
      l2PanelsSizer.add_item(@ConflictingMetadataPanel, :flag => Wx::GROW, :proportion => 1)

      lMainSizer.add_item(l2PanelsSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)
      self.sizer = lMainSizer

      self.fit

    end

    # Get the new data from the components
    #
    # Return:
    # * _String_: The name
    # * <em>Wx::Bitmap</em>: The icon (can be nil)
    def getNewData
      return @ConflictingMetadataPanel.getNewData
    end

  end

end
