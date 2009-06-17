#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Dialog that edits options
  class OptionsDialog < Wx::Dialog

    include Tools

    # The conflicts panel options
    class ConflictsPanel < Wx::Panel

      # Constructor
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iOptions* (<em>map<Symbol,Object></em>): The options to fill in the components
      def initialize(iParent, iOptions)
        super(iParent)

        # Create components
        lSBTags = Wx::StaticBox.new(self, Wx::ID_ANY, 'Tags')
        @RBTagsKey = Wx::RadioBox.new(self, Wx::ID_ANY, 'Tags conflict key based on',
          :choices => [
            'None',
            'Name only',
            'Description (Name + Icon)'
          ],
          :style => Wx::RA_SPECIFY_ROWS
        )
        @RBTagsAction = Wx::RadioBox.new(self, Wx::ID_ANY, 'Action to take in case of Tags conflict',
          :choices => [
            'Ask user',
            'Merge using existing values',
            'Merge using conflicting values',
            'Cancel single conflict',
            'Cancel whole operation'
          ],
          :style => Wx::RA_SPECIFY_ROWS
        )
        lSBShortcuts = Wx::StaticBox.new(self, Wx::ID_ANY, 'Shortcuts')
        @RBShortcutsKey = Wx::RadioBox.new(self, Wx::ID_ANY, 'Shortcuts conflict key based on',
          :choices => [
            'None',
            'Name only',
            'Description (Name + Icon)',
            'Content (URL)',
            'Description and Content'
          ],
          :style => Wx::RA_SPECIFY_ROWS
        )
        @RBShortcutsAction = Wx::RadioBox.new(self, Wx::ID_ANY, 'Action to take in case of Shortcuts conflict',
          :choices => [
            'Ask user',
            'Merge using existing values',
            'Merge using conflicting values',
            'Cancel single conflict',
            'Cancel whole operation'
          ],
          :style => Wx::RA_SPECIFY_ROWS
        )

        # Put everything in sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        # Each static box has a sizer
        lTagsSizer = Wx::StaticBoxSizer.new(lSBTags, Wx::HORIZONTAL)
        lTagsSizer.add_item(@RBTagsKey, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
        lTagsSizer.add_item(@RBTagsAction, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
        lShortcutsSizer = Wx::StaticBoxSizer.new(lSBShortcuts, Wx::HORIZONTAL)
        lShortcutsSizer.add_item(@RBShortcutsKey, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
        lShortcutsSizer.add_item(@RBShortcutsAction, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
        lMainSizer.add_item(lTagsSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
        lMainSizer.add_item(lShortcutsSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
        self.sizer = lMainSizer
        lMainSizer.fit(self)

        # Set default values based on the current options
        @RBTagsKey.selection = iOptions[:tagsUnicity]
        @RBShortcutsKey.selection = iOptions[:shortcutsUnicity]
        @RBTagsAction.selection = iOptions[:tagsConflict]
        @RBShortcutsAction.selection = iOptions[:shortcutsConflict]

      end

      # Fill the options from the components
      #
      # Parameters:
      # * *oOptions* (<em>map<Symbol,Object></em>): The options to fill
      def fillOptions(oOptions)
        oOptions[:tagsUnicity] = @RBTagsKey.selection
        oOptions[:shortcutsUnicity] = @RBShortcutsKey.selection
        oOptions[:tagsConflict] = @RBTagsAction.selection
        oOptions[:shortcutsConflict] = @RBShortcutsAction.selection
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
    # * *iOptions* (<em>map<Symbol,Object></em>): The options to fill in the components
    def initialize(iParent, iOptions)
      super(iParent,
        :title => 'Options',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # Create the notebook
      lNBOptions = Wx::Notebook.new(self)
      # Create the image list for the notebook
      lNotebookImageList = Wx::ImageList.new(16, 16)
      lNBOptions.image_list = lNotebookImageList
      # Make this image list driven by a manager
      lImageListManager = ImageListManager.new(lNotebookImageList, 16, 16)

      # Create panels that will go in tabs
      @OptionsPanels = [
        [ 'Conflicts', 'Conflict.png', ConflictsPanel.new(lNBOptions, iOptions) ]#,
#        [ 'Shortcut Types', 'Image1.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Keymaps', 'Keymaps.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Encryption', 'Encryption.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Toolbars', 'Toolbars.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Integration plugins', 'Image1.png', Wx::Panel.new(lNBOptions) ]
      ]

      # Create each tab
      @OptionsPanels.each do |iPanelInfo|
        iTitle, iIconFileName, iPanel = iPanelInfo
        lNBOptions.add_page(
          iPanel,
          iTitle,
          false,
          lImageListManager.getImageIndex(iPanel.object_id) do
            next Wx::Bitmap.new("#{$PBSRootDir}/Graphics/#{iIconFileName}")
          end
        )
      end

      # The buttons panel
      lButtonsPanel = createButtonsPanel(self)

      # Then put everything in place using sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lMainSizer.add_item(lNBOptions, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 1)
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)
      self.sizer = lMainSizer

      self.fit

    end

    # Get the options from the components
    #
    # Return:
    # * <em>map<Symbol,Object></em>: The options
    def getOptions
      rOptions = {}

      @OptionsPanels.each do |iPanelInfo|
        iTitle, iIconFileName, iPanel = iPanelInfo
        iPanel.fillOptions(rOptions)
      end

      return rOptions
    end

  end

end
