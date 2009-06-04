#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/ChooseIconDialog.rb'

module PBS

  # Dialog that edits a Shortcut
  class EditShortcutDialog < Wx::Dialog

    include Tools

    # Set the BitmapButton icon, based on @Icon and @Type
    def setBBIcon
      lIconBitmap = @Icon
      if (lIconBitmap == nil)
        lIconBitmap = @Type.getIcon
      end
      @BBIcon.bitmap_label = lIconBitmap
      if (lIconBitmap.is_ok)
        @BBIcon.bitmap_label = lIconBitmap
      else
        @BBIcon.bitmap_label = INVALID_ICON
      end
      @BBIcon.size = [ @BBIcon.bitmap_label.width + 4, @BBIcon.bitmap_label.height + 4 ]
    end
    
    # Create the metadata panel
    #
    # Parameters:
    # * *iParent* (_Window_): The parent window
    # * *iSC* (_Shortcut_): The Shortcut containing initial values
    def createMetadataPanel(iParent, iSC)
      @MetadataPanel = Wx::Panel.new(iParent)

      # Create all components
      lSTTitle = Wx::StaticText.new(@MetadataPanel, -1, 'Title')
      @TCTitle = Wx::TextCtrl.new(@MetadataPanel, :value => iSC.Metadata['title'])
      @TCTitle.min_size = [300, @TCTitle.min_size.height]
      lSTIcon = Wx::StaticText.new(@MetadataPanel, -1, 'Icon')
      @BBIcon = Wx::BitmapButton.new(@MetadataPanel, -1, Wx::Bitmap.new)
      evt_button(@BBIcon) do |iEvent|
        # display the icon chooser dialog
        lIconDialog = ChooseIconDialog.new(self, @BBIcon.bitmap_label)
        case lIconDialog.show_modal
        when Wx::ID_OK
          lNewIcon = lIconDialog.getSelectedBitmap
          if (lNewIcon != nil)
            @Icon = lNewIcon
            setBBIcon
          end
        end
      end

      # Put them in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      @MetadataPanel.sizer = lMainSizer
      lMainSizer.add_item([0,0], :proportion => 1)
      lMainSizer.add_item(lSTTitle, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item(@TCTitle, :flag => Wx::GROW, :proportion => 0)
      lIconSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lIconSizer.add_item(lSTIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lIconSizer.add_item([8,0], :proportion => 0)
      lIconSizer.add_item(@BBIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item([0,8], :proportion => 0)
      lMainSizer.add_item(lIconSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item([0,0], :proportion => 1)

      # Fit correctly depending on icon's size
      setBBIcon
      
    end

    # Create the metadata corresponding to the metadata panel
    #
    # Return:
    # * <em>map<String,Object></em>: The corresponding metadata
    def createMetadataFromPanel
      rMetadata = {}

      rMetadata['title'] = @TCTitle.value
      rMetadata['icon'] = @Icon

      return rMetadata
    end

    # Populate a TreeCtrl component with Tags and checkboxes.
    # Keep inserted tags in a map filled by the method.
    #
    # Parameters:
    # * *iRootID* (_Integer_): ID of one of the tree's node where tags will be inserted
    # * *iRootTag* (_Tag_): Tag containing all tags to put in the tree
    # * *iSelectedTags* (<em>map<Tag,nil></em>): The set of selected tags
    def populateCheckedTagsTreeCtrl(iRootID, iRootTag, iSelectedTags)
      iRootTag.Children.each do |iChildTag|
        lChildTagID = @TCTags.append_item(iRootID, iChildTag.Name)
        if (iSelectedTags.has_key?(iChildTag))
          @TCTags.set_item_image(lChildTagID, 1)
        else
          @TCTags.set_item_image(lChildTagID, 0)
        end
        @TCTags.set_item_data(lChildTagID, iChildTag)
        populateCheckedTagsTreeCtrl(lChildTagID, iChildTag, iSelectedTags)
      end
    end

    # Create the tags panel
    #
    # Parameters:
    # * *iParent* (_Window_): The parent window
    # * *iRootTag* (_Tag_): The root tag
    # * *iSelectedTags* (<em>map<Tag,nil></em>): The set of selected tags
    def createTagsPanel(iParent, iRootTag, iSelectedTags)
      @TagsPanel = Wx::Panel.new(iParent)
      # Create components
      lSTTags = Wx::StaticText.new(@TagsPanel, -1, 'Tags')
      # Create the tree
      @TCTags = Wx::TreeCtrl.new(@TagsPanel)
      @RootID = @TCTags.add_root('     ')
      # Create the image list for the tree
      lImageList = createImageList(['Checkbox_UnChecked.png', 'Checkbox_Checked.png'])
      @TCTags.image_list = lImageList
      populateCheckedTagsTreeCtrl(@RootID, iRootTag, iSelectedTags)
      @TCTags.expand_all
      @TCTags.min_size = [200, 300]
      evt_tree_sel_changed(@TCTags.id) do |iEvent|
        # Selection has changed: invert check of selected item
        lSelectedID = @TCTags.get_selection
        if (lSelectedID != 0)
          @TCTags.set_item_image(lSelectedID, 1 - @TCTags.item_image(lSelectedID))
        end
      end

      # Put them into sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      @TagsPanel.sizer = lMainSizer
      lMainSizer.add_item(lSTTags, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item(@TCTags, :flag => Wx::GROW, :proportion => 1)
    end

    # Create the tags map corresponding to the tags panel
    #
    # Return:
    # * <em>map<Tag,nil></em>: The corresponding tags set
    def createTagsFromPanel
      rTags = {}

      @TCTags.traverse do |iItemID|
        if (@TCTags.item_image(iItemID) == 1)
          rTags[@TCTags.get_item_data(iItemID)] = nil
        end
      end

      return rTags
    end

    # Create the buttons panel
    #
    # Parameters:
    # * *iParent* (_Window_): The parent window
    # Return:
    # * _Panel_: The panel containing controls
    def createButtonsPanel(iParent)
      rResult = Wx::Panel.new(iParent)

      # Create buttons
      lBOK = Wx::Button.new(rResult, Wx::ID_OK, 'OK')
      lBCancel = Wx::Button.new(rResult, Wx::ID_CANCEL, 'Cancel')

      # Put them in sizers
      lMainSizer = Wx::StdDialogButtonSizer.new
      rResult.sizer = lMainSizer
      lMainSizer.add_button(lBOK)
      lMainSizer.add_button(lBCancel)
      lMainSizer.realize

      return rResult
    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iSC* (_Shortcut_): The shortcut being edited in this frame
    # * *iRootTag* (_Tag_): The root tag
    def initialize(iParent, iSC, iRootTag)
      @Type = iSC.Type

      super(iParent,
        :title => "Edit Shortcut (#{@Type.pluginName})",
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # This attribute will be changed only if the icon is changed.
      # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
      @Icon = iSC.Metadata['icon']

      # First create all the panels that will fit in this dialog
      @ContentPanel = iSC.Type.createEditPanel(self, iSC)
      createTagsPanel(self, iRootTag, iSC.Tags)
      createMetadataPanel(self, iSC)
      lButtonsPanel = createButtonsPanel(self)
      # Fit them all now, as we will use their true sizes to determine proportions in the sizers
      @ContentPanel.fit
      @MetadataPanel.fit
      @TagsPanel.fit

      # Then put everything in place using sizers

      # Create the main sizer
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      self.sizer = lMainSizer

      # First sizer item is the group of 3 panels (content, metadata and tags)
      l3PanelsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)

      # The first part of the 3 Panels sizer is the group of content and metadata panels
      l2PanelsSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      l2PanelsSizer.add_item(@ContentPanel, :flag => Wx::GROW, :proportion => @ContentPanel.size.height)
      # A little space
      l2PanelsSizer.add_item([0,8], :proportion => 0)
      l2PanelsSizer.add_item(@MetadataPanel, :flag => Wx::GROW, :proportion => @MetadataPanel.size.height)

      lSize = @ContentPanel.size.width
      if (@MetadataPanel.size.width > lSize)
        lSize = @MetadataPanel.size.width
      end
      l3PanelsSizer.add_item(l2PanelsSizer, :flag => Wx::GROW, :proportion => lSize)
      # A little space
      l3PanelsSizer.add_item([8,0], :proportion => 0)
      # The second part of the 3 Panels sizer is the panel of tags
      l3PanelsSizer.add_item(@TagsPanel, :flag => Wx::GROW, :proportion => @TagsPanel.size.width)

      lMainSizer.add_item(l3PanelsSizer, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 1)
      # The second part of the main sizer is the panel containing the buttons
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)

      self.fit

    end

    # Get the new data from the components
    #
    # Return:
    # * _Object_: The Content
    # * <em>map<String,Object></em>: The Metadata
    # * <em>map<Tag,nil></em>: The Tags
    def getNewData
      rNewContent = @Type.createContentFromPanel(@ContentPanel)
      rNewMetadata = createMetadataFromPanel
      rNewTags = createTagsFromPanel

      return rNewContent, rNewMetadata, rNewTags
    end

  end

end
