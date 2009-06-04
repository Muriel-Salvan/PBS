#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/ChooseIconDialog.rb'

module PBS

  # Dialog that edits a Tag
  class EditTagDialog < Wx::Dialog

    include Tools

    # The default Tag icon
    DEFAULT_TAG_ICON = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Tag.png")

    # Set the BitmapButton icon, based on @Icon and @Type
    def setBBIcon
      lIconBitmap = @Icon
      if (lIconBitmap == nil)
        lIconBitmap = DEFAULT_TAG_ICON
      end
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
    # * *iTag* (_Tag_): The Tag containing initial values
    def createMetadataPanel(iParent, iTag)
      @MetadataPanel = Wx::Panel.new(iParent)

      # Create all components
      lSTTitle = Wx::StaticText.new(@MetadataPanel, -1, 'Title')
      @TCTitle = Wx::TextCtrl.new(@MetadataPanel, :value => iTag.Name)
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
    # * *iTag* (_Tag_): The Tag being edited in this frame
    def initialize(iParent, iTag)
      super(iParent,
        :title => 'Edit Tag',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # This attribute will be changed only if the icon is changed.
      # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
      @Icon = iTag.Icon

      # First create all the panels that will fit in this dialog
      createMetadataPanel(self, iTag)
      lButtonsPanel = createButtonsPanel(self)
      # Fit them all now, as we will use their true sizes to determine proportions in the sizers
      @MetadataPanel.fit

      # Then put everything in place using sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      self.sizer = lMainSizer
      lMainSizer.add_item(@MetadataPanel, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)

      self.fit

    end

    # Get the new data from the components
    #
    # Return:
    # * _String_: The name
    # * <em>Wx::Bitmap</em>: The icon (can be nil)
    def getNewData
      return @TCTitle.value, @Icon
    end

  end

end
