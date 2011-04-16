#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Dialog that edits a Shortcut
  class EditShortcutDialog < Wx::Dialog

    # Get the image index corresponding to the status
    #
    # Parameters:
    # * *iStatus* (_Boolean_): Is the status checked ?
    # Return:
    # * _Integer_: The image index
    def getIdxImage(iStatus)
      return @ImageListManager.getImageIndex(iStatus) do
        rBitmap = nil

        if (iStatus)
          rBitmap, lError = getURLContent("#{$PBS_GraphicsDir}/Checkbox_Checked.png", :LocalFileAccess => true) do |iFileName|
            next Wx::Bitmap.new(iFileName)
          end
        else
          rBitmap , lError = getURLContent("#{$PBS_GraphicsDir}/Checkbox_UnChecked.png", :LocalFileAccess => true) do |iFileName|
            next Wx::Bitmap.new(iFileName)
          end
        end

        next rBitmap
      end
    end

    # Populate a TreeCtrl component with Tags and checkboxes.
    #
    # Parameters:
    # * *iRootID* (_Integer_): ID of one of the tree's node where tags will be inserted
    # * *iRootTag* (_Tag_): Tag containing all tags to put in the tree
    # * *iSelectedTags* (<em>map<Tag,nil></em>): The set of selected tags
    def populateCheckedTagsTreeCtrl(iRootID, iRootTag, iSelectedTags)
      iRootTag.Children.each do |iChildTag|
        lChildTagID = @TCTags.append_item(iRootID, iChildTag.Name)
        @TCTags.set_item_image(lChildTagID, getIdxImage(iSelectedTags.has_key?(iChildTag)))
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
      lSTTags = Wx::StaticText.new(@TagsPanel, Wx::ID_ANY, 'Tags')
      # Create the tree
      @TCTags = Wx::TreeCtrl.new(@TagsPanel)
      @RootID = @TCTags.add_root('     ')
      # Create the image list manager for the tree
      lImageList = Wx::ImageList.new(16, 16)
      @TCTags.image_list = lImageList
      @ImageListManager = RUtilAnts::GUI::ImageListManager.new(lImageList, 16, 16)
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
    # * *iSC* (_Shortcut_): The Shortcut containing info to edit (or nil if initial values needed)
    # * *iRootTag* (_Tag_): The root tag
    # * *iController* (_Controller_): The Controller
    # * *iType* (_ShortcutType_): The Shortcut Type used (ignored if iSC != nil) [optional = nil]
    # * *iInitialTag* (_Tag_): The initial Tag (ignored if iSC != nil) (can be nil for the Root Tag) [optional = nil]
    def initialize(iParent, iSC, iRootTag, iController, iType = nil, iInitialTag = nil)
      if (iSC == nil)
        @Type = iType
      else
        @Type = iSC.Type
      end

      super(iParent,
        :title => "Edit Shortcut (#{@Type.pluginDescription[:PluginName]})",
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # First create all the panels that will fit in this dialog
      require 'pbs/Windows/ContentMetadataPanel'
      @ContentMetadataPanel = ContentMetadataPanel.new(self, @Type, iController)
      if (iSC == nil)
        lTags = {}
        if (iInitialTag != nil)
          lTags[iInitialTag] = nil
        end
        createTagsPanel(self, iRootTag, lTags)
        @ContentMetadataPanel.setData(iType.createEmptyContent, {'title' => 'New Shortcut', 'icon' => nil})
      else
        createTagsPanel(self, iRootTag, iSC.Tags)
        @ContentMetadataPanel.setData(iSC.Content, iSC.Metadata)
      end
      lButtonsPanel = createButtonsPanel(self)
      # Fit them all now, as we will use their true sizes to determine proportions in the sizers
      @ContentMetadataPanel.fit
      @TagsPanel.fit

      # Then put everything in place using sizers

      # Create the main sizer
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      self.sizer = lMainSizer

      # First sizer item is the group of 3 panels (content, metadata and tags)
      l3PanelsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)

      l3PanelsSizer.add_item(@ContentMetadataPanel, :flag => Wx::GROW, :proportion => @ContentMetadataPanel.size.width)
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
    def getData
      rNewContent, rNewMetadata = @ContentMetadataPanel.getData
      rNewTags = createTagsFromPanel

      return rNewContent, rNewMetadata, rNewTags
    end

  end

end
