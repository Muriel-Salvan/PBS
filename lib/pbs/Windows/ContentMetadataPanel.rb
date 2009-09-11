#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Windows/ChooseIconDialog.rb'

module PBS

  # Panel that displays content and metadata
  class ContentMetadataPanel < Wx::Panel

    # Panel containing the Metadata
    class MetadataPanel < Wx::Panel

      # Set the BitmapButton icon, based on @Icon and @Type
      def setBBIcon
        lIconBitmap = @Icon
        if (lIconBitmap == nil)
          lIconBitmap = @Controller.getPluginBitmap(@Type.pluginDescription)
        end
        if (lIconBitmap.is_ok)
          @BBIcon.bitmap_label = lIconBitmap
        else
          @BBIcon.bitmap_label = getGraphic('InvalidIcon.png')
        end
        @BBIcon.size = [ @BBIcon.bitmap_label.width + 4, @BBIcon.bitmap_label.height + 4 ]
      end

      # Constructor
      #
      # Parameters:
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window
      # * *iType* (_ShortcutType_): The Shortcut Type used
      # * *iController* (_Controller_): The Controller
      # * *iContentPanel* (<em>Wx::Panel</em>): The panel storing the content, used only to get default values from it
      def initialize(iParentWindow, iType, iController, iContentPanel)
        super(iParentWindow)

        @Type = iType
        @Controller = iController
        # @Icon will be changed only if the icon is changed.
        # It is used instead of the Wx::BitmapButton::bitmap_label because it can be nil, and in this case we don't want to replace it with the default icon internally.
        @Icon = nil

        # Create all components
        lSTTitle = Wx::StaticText.new(self, Wx::ID_ANY, 'Title')
        @TCTitle = Wx::TextCtrl.new(self)
        @TCTitle.min_size = [300, @TCTitle.min_size.height]
        lSTIcon = Wx::StaticText.new(self, Wx::ID_ANY, 'Icon')
        @BBIcon = Wx::BitmapButton.new(self, Wx::ID_ANY, Wx::Bitmap.new)
        lBIconFromContent = Wx::Button.new(self, Wx::ID_ANY, '<- from Shortcut content')

        # Events
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
        evt_button(lBIconFromContent) do |iEvent|
          # Ask the content to give the icon
          @Icon = @Type.getDefaultIconFromContent(iContentPanel.getData)
          setBBIcon
        end

        # Put them in sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item([0,0], :proportion => 1)
        lMainSizer.add_item(lSTTitle, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item(@TCTitle, :flag => Wx::GROW, :proportion => 0)

        lIconSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lIconSizer.add_item(lSTIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lIconSizer.add_item([8,0], :proportion => 0)

        lIconButtonsSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lIconButtonsSizer.add_item(@BBIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lIconButtonsSizer.add_item(lBIconFromContent, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

        lIconSizer.add_item(lIconButtonsSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        
        lMainSizer.add_item([0,8], :proportion => 0)
        lMainSizer.add_item(lIconSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item([0,0], :proportion => 1)
        self.sizer = lMainSizer
      end

      # Create the metadata corresponding to the metadata panel
      #
      # Return:
      # * <em>map<String,Object></em>: The corresponding metadata
      def getData
        rMetadata = {}

        rMetadata['title'] = @TCTitle.value
        rMetadata['icon'] = @Icon

        return rMetadata
      end

      # Set the metadata panel's content from a given metadata
      #
      # Parameters:
      # * *iMetadata* (<em>map<String,Object></em>): The corresponding metadata
      def setData(iMetadata)
        @TCTitle.value = iMetadata['title']
        @Icon = iMetadata['icon']
        setBBIcon
      end

    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iType* (_ShortcutType_): The Shortcut Type used
    # * *iController* (_Controller_): The Controller
    def initialize(iParent, iType, iController)
      super(iParent)

      @Type = iType
      # First create all the panels that will fit in this panel
      @ContentPanel = eval("#{@Type.class}::EditPanel.new(self)")
      @MetadataPanel = MetadataPanel.new(self, @Type, iController, @ContentPanel)

      # Then put everything in place using sizers
      # Fit them all now, as we will use their true sizes to determine proportions in the sizers
      @ContentPanel.fit
      @MetadataPanel.fit
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lMainSizer.add_item(@ContentPanel, :flag => Wx::GROW, :proportion => @ContentPanel.size.height)
      # A little space
      lMainSizer.add_item([0,8], :proportion => 0)
      lMainSizer.add_item(@MetadataPanel, :flag => Wx::GROW, :proportion => @MetadataPanel.size.height)
      self.sizer = lMainSizer

    end

    # Get the new data from the components
    #
    # Return:
    # * _Object_: The Content
    # * <em>map<String,Object></em>: The Metadata
    def getData
      return @ContentPanel.getData, @MetadataPanel.getData
    end

    # Set the data in the components
    #
    # Parameters:
    # * *iContent* (_Object_): The Content
    # * *iMetadata* (<em>map<String,Object></em>): The Metadata
    def setData(iContent, iMetadata)
      @ContentPanel.setData(iContent)
      @MetadataPanel.setData(iMetadata)
    end

  end

end
