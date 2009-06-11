#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/ChooseIconDialog.rb'

module PBS

  # Panel that edits Tag's metadata
  class TagMetadataPanel < Wx::Panel

    include Tools

    # The default Tag icon
    DEFAULT_TAG_ICON = Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Tag.png")

    # Set the BitmapButton icon, based on @Icon
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
    # * *iName* (_String_): The Tag name
    # * *iIcon* (<em>Wx::Bitmap</em>): The icon
    def initialize(iParent, iName, iIcon)
      super(iParent)

      # This attribute will be changed only if the icon is changed.
      # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
      @Icon = iIcon
      
      # Create all components
      lSTTitle = Wx::StaticText.new(self, -1, 'Title')
      @TCTitle = Wx::TextCtrl.new(self, :value => iName)
      @TCTitle.min_size = [300, @TCTitle.min_size.height]
      lSTIcon = Wx::StaticText.new(self, -1, 'Icon')
      @BBIcon = Wx::BitmapButton.new(self, -1, Wx::Bitmap.new)
      evt_button(@BBIcon) do |iEvent|
        # display the icon chooser dialog
        showModal(ChooseIconDialog, self, @BBIcon.bitmap_label) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            lNewIcon = iDialog.getSelectedBitmap
            if (lNewIcon != nil)
              @Icon = lNewIcon
              setBBIcon
            end
          end
        end
      end

      # Put them in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
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
      self.sizer = lMainSizer

      # Fit correctly depending on icon's size
      setBBIcon
      
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
