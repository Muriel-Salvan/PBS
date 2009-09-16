#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Types

    class PortableShell

      # The panel that edits contents from this Shortcut type
      class EditPanel < Wx::Panel

        # Constructor
        #
        # Parameters:
        # * *iParent* (_Window_): The parent window
        def initialize(iParent)
          super(iParent)

          # Special care of startup
          lStartupFinished = false

          # Map of Edit pages, per platform ID
          # map< String, PBS::Types::Shell::EditPanel >
          @EditPanels = {}

          # We create an advanced notebook, to get the close buttons on tabs
          @NBShells = Wx::AuiNotebook.new(
            self,
            Wx::ID_ANY,
            Wx::DEFAULT_POSITION,
            Wx::DEFAULT_SIZE,
            Wx::AUI_NB_SCROLL_BUTTONS|Wx::AUI_NB_CLOSE_ON_ACTIVE_TAB
          )

          # Create a panel for the current platform
          addNewEditPanel(RUBY_PLATFORM)

          # Create a dummy panel that will instantiate a new Panel
          lNewPanel = Wx::Panel.new(self)
          @NBShells.add_page(
            lNewPanel,
            '',
            false,
            getGraphic('NewTab.png')
          )

          # Put in sizers
          lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
          lMainSizer.add_item(@NBShells, :flag => Wx::GROW, :proportion => 1)
          self.sizer = lMainSizer

          # Events
          # Close a Tab in the notebook
          @NBShells.evt_auinotebook_page_close(@NBShells) do |iEvent|
            # The page iEvent.selection has been closed
            if (@EditPanels.size == 1)
              logErr 'You cannot close the last parameters.'
              iEvent.veto
            else
              # Remove page number iEvent.selection, and get back to the first page if it was the last one
              if (iEvent.selection == @EditPanels.size-1)
                @NBShells.selection = 0
              end
              lEditPanelToDelete = @NBShells.get_page(iEvent.selection)
              @EditPanels.delete_if do |iPlatformID, iEditPanel|
                if (lEditPanelToDelete == iEditPanel)
                  # Remove this one
                  # TODO: Check if this is correct to do it
                  #iEditPanel.destroy
                  # Delete it from the list
                  next true
                else
                  next false
                end
              end
            end
          end
          # Show the last tab (+)
          @NBShells.evt_auinotebook_page_changing(@NBShells) do |iEvent|
            # TODO (WxRuby): The event is not triggered after a call to .selection=. Correct this bug.
            if ((lStartupFinished) and
                (iEvent.selection == @EditPanels.size))
              # We clicked on it to show it
              # Ask for the name of the platform
              lNewPlatformName = nil
              showModal(Wx::TextEntryDialog, self, 'Please enter the platform\'s name', 'Name of the platform', '') do |iModalResult, iDialog|
                if (iModalResult == Wx::ID_OK)
                  lNewPlatformName = iDialog.get_value
                end
              end
              if (lNewPlatformName != nil)
                # Check if it is not already taken
                if (@EditPanels[lNewPlatformName] == nil)
                  # Create a new one, and set it active
                  addNewEditPanel(lNewPlatformName)
                  @NBShells.selection = @NBShells.get_page_index(@EditPanels[lNewPlatformName])
                else
                  logErr "Sorry, but platform #{lNewPlatformName} already has parameters defined."
                  lNewPlatformName = nil
                end
              end
              if (lNewPlatformName == nil)
                # Select the first page
                @NBShells.selection = 0
              end
              # Finally, we cancel the event
              iEvent.veto
            end
          end

          # Fit everything
          self.fit

          lStartupFinished = true

        end

        # Get the content from the controls
        #
        # Return:
        # * _Object_: The corresponding content, which will be associated to a shortcut
        def getData
          rContent = {}

          # Parse every page of the notebook
          @EditPanels.each do |iPlatformID, iEditPage|
            rContent[iPlatformID] = iEditPage.getData
          end

          return rContent
        end

        # Set the Panel's contents based on a given content
        #
        # Parameters:
        # * *iContent* (_Object_): The content containing values to put in the panel
        def setData(iContent)
          iContent.each do |iPlatformID, iShellContent|
            # Find if we already have an Edit panel for iPlatformID
            if (@EditPanels[iPlatformID] == nil)
              addNewEditPanel(iPlatformID)
            end
            @EditPanels[iPlatformID].setData(iShellContent)
          end
          # Remove panels that are not part anymore of the data to be set
          @EditPanels.delete_if do |iPlatformID, iEditPanel|
            if (iContent[iPlatformID] == nil)
              # Remove this one
              @NBShells.remove_page(@NBShells.get_page_index(iEditPanel))
              # Free the Window itself
              # TODO: Check if this is correct to do it
              #iEditPanel.destroy
              # Delete it from the list
              next true
            else
              next false
            end
          end
          # Fit everything
          self.fit
        end

        private

        # Add a new platform panel
        #
        # Parameters:
        # * *iPlatformID* (_String_): The platform ID
        def addNewEditPanel(iPlatformID)
          @EditPanels[iPlatformID] = PBS::Types::Shell::EditPanel.new(@NBShells)
          lBitmap = nil
          if (File.exists?("#{$PBS_GraphicsDir}/Platforms/#{iPlatformID}.png"))
            lBitmap = getGraphic("Platforms/#{iPlatformID}.png")
          else
            lBitmap = getGraphic('Plugin.png')
          end
          @NBShells.insert_page(
            @NBShells.page_count-1,
            @EditPanels[iPlatformID],
            iPlatformID,
            false,
            lBitmap
          )
        end

      end

      # Constructor
      def initialize
        # Get a reference on the Shell plugin
        @ShellPlugin, lError = getPluginInstance('Type', 'Shell')
      end

      # Create an empty content.
      # This is used for putting default values in the NewShortcut dialog.
      #
      # Return:
      # * _Object_: The default content
      def createEmptyContent
        return { RUBY_PLATFORM => @ShellPlugin.createEmptyContent }
      end

      # Get a simple summary of a given content created by this Type.
      # This could be used in tool tips for example.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # Return:
      # * _String_: The content's summary
      def getContentSummary(iContent)
        return @ShellPlugin.getContentSummary(iContent[RUBY_PLATFORM])
      end

      # Run a given content
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      def run(iContent)
        @ShellPlugin.run(iContent[RUBY_PLATFORM])
      end

      # Fill a given XML element with a content.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # * *oXMLContentElement* (<em>REXML::Element</em>): The XML element to fill with the data
      def getContentAsXMLText(iContent, oXMLContentElement)
        iContent.each do |iPlatformID, iPlatformContent|
          lXMLPlatformContentElement = oXMLContentElement.add_element('platform')
          lXMLPlatformContentElement['name'] = iPlatformID
          @ShellPlugin.getContentAsXMLText(iPlatformContent, lXMLPlatformContentElement)
        end
      end

      # Create a content from an XML text.
      # The XML text has been created by getContentAsXMLText.
      #
      # Parameters:
      # * *iXMLContentElement* (<em>REXML::Element</em>): The XML element
      # Return:
      # * _Object_: Content created based on this XML element
      def createContentFromXMLText(iXMLContentElement)
        rContent = {}

        iXMLContentElement.elements['platform'].each do |iXMLPlatformContentElement|
          rContent[iXMLPlatformContentElement['name']] = @ShellPlugin.createContentFromXMLText(iXMLPlatformContentElement)
        end

        return rContent
      end

      # Get the metadata best reflecting the content.
      #
      # Parameters:
      # * *iContent* (_Object_): The content to read from
      # Return:
      # * <em>map<String,Object></em>: The corresponding metadata
      def getMetadataFromContent(iContent)
        return @ShellPlugin.getMetadataFromContent(iContent[RUBY_PLATFORM])
      end

    end

  end

end
