#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/ContentMetadataPanel.rb'

module PBS

  # Dialog that edits a Shortcut
  class ResolveShortcutConflictDialog < Wx::Dialog

    include Tools

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
      # TODO: Use it
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
    # * *iSC* (_Shortcut_): The Shortcut containing existing info
    # * *iContent* (_Object_): The content issuing a conflict
    # * *iMetadata* (<em>map<String,Object></em>): The Metadata issuing a conflict
    def initialize(iParent, iSC, iContent, iMetadata)
      super(iParent,
        :title => "Resolve Shortcut conflict (#{iSC.Type.pluginName})",
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # First create all the panels that will fit in this dialog
      @ExistingContentMetadataPanel = ContentMetadataPanel.new(self, iSC.Type, iSC.Content, iSC.Metadata)
      # Set it read-only
      @ExistingContentMetadataPanel.enable(false)
      @ConflictingContentMetadataPanel = ContentMetadataPanel.new(self, iSC.Type, iContent, iMetadata)
      lButtonsPanel = createButtonsPanel(self)

      # Fit them all now, as we will use their true sizes to determine proportions in the sizers
      @ExistingContentMetadataPanel.fit
      @ConflictingContentMetadataPanel.fit

      # Then put everything in place using sizers

      # Create the main sizer
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      self.sizer = lMainSizer

      # First sizer item is the group of 2 content/metadata panels
      l2PanelsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      l2PanelsSizer.add_item(@ExistingContentMetadataPanel, :flag => Wx::GROW, :proportion => 1)
      l2PanelsSizer.add_item(@ConflictingContentMetadataPanel, :flag => Wx::GROW, :proportion => 1)

      lMainSizer.add_item(l2PanelsSizer, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 1)
      # The second part of the main sizer is the panel containing the buttons
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)

      self.fit

    end

    # Get the new data from the components
    #
    # Return:
    # * _Object_: The Content
    # * <em>map<String,Object></em>: The Metadata
    def getNewData
      return @ConflictingContentMetadataPanel.getNewData
    end

  end

end
