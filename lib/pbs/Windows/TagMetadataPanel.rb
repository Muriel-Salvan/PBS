#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Panel that edits Tag's metadata
  class TagMetadataPanel < Wx::Panel

    # Set the BitmapButton icon, based on @Icon
    def setBBIcon
      lIconBitmap = @Icon
      if (lIconBitmap == nil)
        lIconBitmap = getGraphic('Tag.png')
      end
      if (lIconBitmap.is_ok)
        @BBIcon.bitmap_label = lIconBitmap
      else
        @BBIcon.bitmap_label = getGraphic('InvalidIcon.png')
      end
      @BBIcon.size = [ @BBIcon.bitmap_label.width + 4, @BBIcon.bitmap_label.height + 4 ]
    end

    # Create the metadata panel
    #
    # Parameters::
    # * *iParent* (_Window_): The parent window
    def initialize(iParent)
      super(iParent)

      # This attribute will be changed only if the icon is changed.
      # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
      @Icon = nil
      
      # Create all components
      lSTTitle = Wx::StaticText.new(self, Wx::ID_ANY, 'Title')
      @TCTitle = Wx::TextCtrl.new(self)
      @TCTitle.min_size = [300, @TCTitle.min_size.height]
      lSTIcon = Wx::StaticText.new(self, Wx::ID_ANY, 'Icon')
      @BBIcon = Wx::BitmapButton.new(self, Wx::ID_ANY, Wx::Bitmap.new)
      evt_button(@BBIcon) do |iEvent|
        # display the icon chooser dialog
        require 'pbs/Windows/ChooseIconDialog'
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

    end

    # Get the new data from the components
    #
    # Return::
    # * _String_: The name
    # * <em>Wx::Bitmap</em>: The icon (can be nil)
    def getData
      return @TCTitle.value, @Icon
    end

    # Set the data in the components
    #
    # Parameters::
    # * *iName* (_String_): The name
    # * *iIcon* (<em>Wx::Bitmap</em>): The icon (can be nil)
    def setData(iName, iIcon)
      @TCTitle.value = iName
      @Icon = iIcon
      setBBIcon
    end

  end

end
