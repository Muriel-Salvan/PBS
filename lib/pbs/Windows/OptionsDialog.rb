#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Windows/OptionsPanels/ConflictsPanel'
require 'pbs/Windows/OptionsPanels/IntegrationPanel'

module PBS

  # Dialog that edits options
  class OptionsDialog < Wx::Dialog

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
      lBOpen = Wx::Button.new(rResult, Wx::ID_OPEN, 'Open ...')
      lBSave = Wx::Button.new(rResult, Wx::ID_SAVE, 'Save ...')

      # Put them in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lMainSizer.add_item(lBOpen, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item([8,0], :proportion => 0)
      lMainSizer.add_item(lBSave, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item([0,0], :proportion => 1)
      lMainSizer.add_item(lBCancel, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lMainSizer.add_item([8,0], :proportion => 0)
      lMainSizer.add_item(lBOK, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      rResult.sizer = lMainSizer

      # Events
      evt_button(lBOK) do |iEvent|
        self.end_modal(Wx::ID_OK)
      end
      evt_button(lBCancel) do |iEvent|
        self.end_modal(Wx::ID_CANCEL)
      end
      evt_button(lBOpen) do |iEvent|
        # Display Open dialog
        showModal(Wx::FileDialog, self,
          :message => 'Open options file',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'PBS Options (*.pbso)|*.pbso'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            setOptions(openOptionsData(iDialog.path))
          end
        end
      end
      evt_button(lBSave) do |iEvent|
        # Display Save dialog
        showModal(Wx::FileDialog, self,
          :message => 'Save options file',
          :style => Wx::FD_SAVE|Wx::FD_OVERWRITE_PROMPT,
          :wildcard => 'PBS Options (*.pbso)|*.pbso'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            # Perform save
            saveOptionsData(getOptions, iDialog.path)
          end
        end

      end

      return rResult
    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iOptions* (<em>map<Symbol,Object></em>): The options to fill in the components
    # * *iController* (_Controller_): The controller, used to get plugins specific data
    def initialize(iParent, iOptions, iController)
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
      lImageListManager = RUtilAnts::GUI::ImageListManager.new(lNotebookImageList, 16, 16)

      # Create panels that will go in tabs
      @OptionsPanels = [
        [ 'Conflicts', 'Conflict.png', ConflictsPanel.new(lNBOptions) ],
#        [ 'Shortcut Types', 'Image1.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Keymaps', 'Keymaps.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Encryption', 'Encryption.png', Wx::Panel.new(lNBOptions) ],
#        [ 'Toolbars', 'Toolbars.png', Wx::Panel.new(lNBOptions) ],
        [ 'Integration plugins', 'Plugin.png', IntegrationPanel.new(lNBOptions, iController) ]
      ]

      setOptions(iOptions)

      # Create each tab
      @OptionsPanels.each do |iPanelInfo|
        iTitle, iIconFileName, iPanel = iPanelInfo
        lNBOptions.add_page(
          iPanel,
          iTitle,
          false,
          lImageListManager.getImageIndex(iPanel.object_id) do
            next Wx::Bitmap.new("#{$PBS_GraphicsDir}/#{iIconFileName}")
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

    # Set panels values based on options
    #
    # Parameters:
    # * *iOptions* (<em>map<Symbol,Object></em>): The options to fill in the components
    def setOptions(iOptions)
      # Fill panels components with options
      @OptionsPanels.each do |iPanelInfo|
        iTitle, iIconFileName, iPanel = iPanelInfo
        iPanel.setOptions(iOptions)
      end
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
