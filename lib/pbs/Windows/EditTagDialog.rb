#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Dialog that edits a Tag
  class EditTagDialog < Wx::Dialog

    # Create the buttons panel
    #
    # Parameters::
    # * *iParent* (_Window_): The parent window
    # Return::
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
    # Parameters::
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iTag* (_Tag_): The Tag being edited in this frame (can be nil for default values)
    def initialize(iParent, iTag)
      super(iParent,
        :title => 'Edit Tag',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # First create all the panels that will fit in this dialog
      require 'pbs/Windows/TagMetadataPanel'
      @MetadataPanel = TagMetadataPanel.new(self)
      if (iTag == nil)
        @MetadataPanel.setData('New Tag', nil)
      else
        @MetadataPanel.setData(iTag.Name, iTag.Icon)
      end
      lButtonsPanel = createButtonsPanel(self)
      # Fit them all now, as we will use their true sizes to determine proportions in the sizers
      @MetadataPanel.fit

      # Then put everything in place using sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lMainSizer.add_item(@MetadataPanel, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)
      self.sizer = lMainSizer

      self.fit

    end

    # Get the new data from the components
    #
    # Return::
    # * _String_: The name
    # * <em>Wx::Bitmap</em>: The icon (can be nil)
    def getData
      return @MetadataPanel.getData
    end

  end

end
