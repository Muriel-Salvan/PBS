#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Types

    class Shell

      # The panel that edits contents from this Shortcut type
      class EditPanel < Wx::Panel

        # Constructor
        #
        # Parameters:
        # * *iParent* (_Window_): The parent window
        def initialize(iParent)
          super(iParent)

          # Create all components
          lSTCmd = Wx::StaticText.new(self, Wx::ID_ANY, 'Shell command')
          lBBOpen = Wx::BitmapButton.new(self, Wx::ID_ANY, getGraphic('Open.png'))
          @TCCmd = Wx::TextCtrl.new(self)
          @TCCmd.min_size = [300, @TCCmd.min_size.height]
          lSTDir = Wx::StaticText.new(self, Wx::ID_ANY, 'Working directory')
          @TCDir = Wx::TextCtrl.new(self)
          @TCDir.min_size = [300, @TCDir.min_size.height]
          @CBTerminal = Wx::CheckBox.new(self, Wx::ID_ANY, 'Run it from a terminal')

          # Put them in sizers
          lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
          lMainSizer.add_item([0,0], :proportion => 1)
          lMainSizer.add_item(lSTCmd, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

          lCmdSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
          lCmdSizer.add_item(@TCCmd, :flag => Wx::ALIGN_CENTRE, :proportion => 1)
          lCmdSizer.add_item([8,0], :flag => Wx::ALIGN_CENTRE, :proportion => 0)
          lCmdSizer.add_item(lBBOpen, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

          lMainSizer.add_item(lCmdSizer, :flag => Wx::GROW, :proportion => 0)
          lMainSizer.add_item([0,8], :proportion => 0)
          lMainSizer.add_item(lSTDir, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
          lMainSizer.add_item(@TCDir, :flag => Wx::GROW, :proportion => 0)
          lMainSizer.add_item([0,8], :proportion => 0)
          lMainSizer.add_item(@CBTerminal, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
          lMainSizer.add_item([0,0], :proportion => 1)
          self.sizer = lMainSizer

          # Events
          evt_button(lBBOpen) do |iEvent|
            # Open dialog
            # Get the executables filters
            lExtensions = "*#{$rUtilAnts_Platform_Info.getExecutableExtensions.join(';*')}"
            showModal(Wx::FileDialog, self,
              :message => 'Open program',
              :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
              :wildcard => "Executable files (#{lExtensions})|#{lExtensions}"
            ) do |iModalResult, iDialog|
              case iModalResult
              when Wx::ID_OK
                # If there are some spaces, add surrounding " "
                if (iDialog.path.include?(' '))
                  @TCCmd.value = "\"#{iDialog.path}\""
                else
                  @TCCmd.value = iDialog.path
                end
              end
            end
          end

        end

        # Get the content from the controls
        #
        # Return:
        # * _Object_: The corresponding content, which will be associated to a shortcut
        def getData
          return [ @TCCmd.value, @TCDir.value, @CBTerminal.value ]
        end

        # Set the Panel's contents based on a given content
        #
        # Parameters:
        # * *iContent* (_Object_): The content containing values to put in the panel
        def setData(iContent)
          lCmd, lDir, lInTerminal = iContent
          if (lDir == nil)
            lDir = ''
          end
          @TCCmd.value = lCmd
          @TCDir.value = lDir
          @CBTerminal.value = lInTerminal
        end

      end

      # Create an empty content.
      # This is used for putting default values in the NewShortcut dialog.
      #
      # Return:
      # * _Object_: The default content
      def createEmptyContent
        return [ 'echo "Hello World"', nil, false ]
      end

      # Get a simple summary of a given content created by this Type.
      # This could be used in tool tips for example.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # Return:
      # * _String_: The content's summary
      def getContentSummary(iContent)
        return iContent[0]
      end

      # Run a given content
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      def run(iContent)
        lCmd, lDir, lInTerminal = iContent
        # First, change to the directory
        lOldDir = nil
        if ((lDir != nil) and
            (!lDir.empty?))
          lOldDir = Dir.getwd
          # Eventually remove quotes from lDir
          if ((lDir[0..0] == '"') and
              (lDir[-1..-1] == '"'))
            lDir = lDir[1..-2]
          end
          Dir.chdir(lDir)
        end
        # Execute command
        lException = $rUtilAnts_Platform_Info.execShellCmdNoWait(lCmd, lInTerminal)
        if (lException != nil)
          logErr "Error while executing \"#{lCmd}\": #{lException}"
        end
        # Change back the current directory
        if (lOldDir != nil)
          Dir.chdir(lOldDir)
        end
      end

      # Fill a given XML element with a content.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # * *oXMLContentElement* (<em>REXML::Element</em>): The XML element to fill with the data
      def getContentAsXMLText(iContent, oXMLContentElement)
        lCmdXMLElement = oXMLContentElement.add_element('cmd')
        lCmdXMLElement.text = iContent[0]
        lDirXMLElement = oXMLContentElement.add_element('dir')
        lDirXMLElement.text = iContent[1]
        if (iContent[2])
          oXMLContentElement.add_element('terminal')
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
        return [
          iXMLContentElement.elements['cmd'].text,
          iXMLContentElement.elements['dir'].text,
          (iXMLContentElement.elements['terminal'] != nil)
        ]
      end

      # Get the metadata best reflecting the content.
      #
      # Parameters:
      # * *iContent* (_Object_): The content to read from
      # Return:
      # * <em>map<String,Object></em>: The corresponding metadata
      def getMetadataFromContent(iContent)
        rMetadata = {}

        # Get the icon from the executable
        # Test the format '"ExeName" Parameters'
        lMatch = iContent[0].match(/^\"([^\"]*)\".*$/)
        if (lMatch == nil)
          lMatch = iContent[0].match(/^([^ ]*).*$/)
        end
        if (lMatch == nil)
          logErr "Unable to get executable file name from #{iContent[0]}"
        else
          lExeFileName = lMatch[1]
          lIcon = nil
          lTitle = 'Shell program'
          if (File.exists?(lExeFileName))
            lTitle = File.basename(lExeFileName)[0..-1-File.extname(lExeFileName).size]
            # Get icon from it
            lIcon, lError = getBitmapFromURL(lExeFileName)
            if (lIcon == nil)
              logErr "Error while getting icon from #{lExeFileName}: #{lError}"
            end
          else
            # Find lExeFileName among the path
            lNewExeFileName = findExeInPath(lExeFileName)
            if (lNewExeFileName == nil)
              logErr "File #{lExeFileName} does not exist in the PATH."
            else
              lTitle = File.basename(lNewExeFileName)[0..-1-File.extname(lNewExeFileName).size]
              # Get icon from it
              lIcon, lError = getBitmapFromURL(lNewExeFileName)
              if (lIcon == nil)
                logErr "Error while getting icon from #{lNewExeFileName}: #{lError}"
              end
            end
          end
          rMetadata['icon'] = lIcon
          rMetadata['title'] = lTitle
        end
        if (rMetadata['title'] == nil)
          rMetadata['title'] = '--- No title ---'
        end

        return rMetadata
      end

    end

  end

end
