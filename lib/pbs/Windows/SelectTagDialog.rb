#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Select Tag Dialog
  class SelectTagDialog < Wx::Dialog

    # Populate a TreeCtrl component with Tags.
    #
    # Parameters:
    # * *iRootID* (_Integer_): ID of one of the tree's node where tags will be inserted
    # * *iRootTag* (_Tag_): Tag containing all tags to put in the tree
    # * *iSelectedTags* (<em>map<Tag,nil></em>): The set of selected tags
    def populateTagsTreeCtrl(iRootID, iRootTag)
      iRootTag.Children.each do |iChildTag|
        lChildTagID = @TCTags.append_item(iRootID, iChildTag.Name)
        lIdxImage = @ImageListManager.getImageIndex(iChildTag.Icon) do
          next @Controller.getTagIcon(iChildTag)
        end
        @TCTags.set_item_image(lChildTagID, lIdxImage)
        @TCTags.set_item_data(lChildTagID, iChildTag)
        populateTagsTreeCtrl(lChildTagID, iChildTag)
      end
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
    # * *iRootTag* (_Tag_): Root Tag to display
    # * *iController* (_Controller_): Controller
    def initialize(iParent, iRootTag, iController)
      super(iParent,
        :title => 'Select Tag',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      @Controller = iController

      # Create components
      @TCTags = Wx::TreeCtrl.new(self, Wx::ID_ANY,
        :style => Wx::TR_HAS_BUTTONS
      )
      # Create the image list for the tree
      lTreeImageList = Wx::ImageList.new(16, 16)
      @TCTags.set_image_list(lTreeImageList)
      # Make this image list driven by a manager
      @ImageListManager = RUtilAnts::GUI::ImageListManager.new(lTreeImageList, 16, 16)
      # Fill the tree
      lRootID = @TCTags.add_root('Root')
      @TCTags.set_item_data(lRootID, iRootTag)
      populateTagsTreeCtrl(lRootID, iRootTag)
      @TCTags.expand_all
      @TCTags.min_size = [200, 300]
      # The underlying buttons
      lButtonsPanel = createButtonsPanel(self)

      # Sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lMainSizer.add_item(@TCTags, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)
      self.sizer = lMainSizer
    end

    # Return the selected Tag, or nil if none
    #
    # Return:
    # * _Tag_: The selected Tag, or nil if none
    def getSelectedTag
      rTag = nil

      if (@TCTags.selection != 0)
        rTag = @TCTags.get_item_data(@TCTags.selection)
      end

      return rTag
    end

  end

end
