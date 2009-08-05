#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Types

    class Shell

      include Tools

      # The panel that edits contents from this Shortcut type
      class EditPanel < Wx::Panel

        include Tools

        ICON_OPEN = Tools::loadBitmap('Open.png')

        # Constructor
        #
        # Parameters:
        # * *iParent* (_Window_): The parent window
        def initialize(iParent)
          super(iParent)

          # Create all components
          lSTCmd = Wx::StaticText.new(self, Wx::ID_ANY, 'Shell command')
          lBBOpen = Wx::BitmapButton.new(self, Wx::ID_ANY, ICON_OPEN)
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
            lExtensions = "*#{$PBS_Platform.getExecutableExtensions.join(';*')}"
            showModal(Wx::FileDialog, self,
              :message => 'Open program',
              :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
              :wildcard => "Executable files (#{lExtensions})|#{lExtensions}"
            ) do |iModalResult, iDialog|
              case iModalResult
              when Wx::ID_OK
                # TODO: Check if we don't need to escape space characters or add " "
                @TCCmd.value = iDialog.path
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
          Dir.chdir(lDir)
        end
        # Execute command
        lException = $PBS_Platform.execShellCmdNoWait(lCmd, lInTerminal)
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
        # TODO: Delete the following
        # THIS SECTION IS NEEDED TO READ XML FILES STORING SHELL SHORTCUTS THAT WERE EXPORTED WITH PBS VERSION < 0.0.4
        # REMOVE THIS COMMENT AND RESTART PBS TO LOAD XML FILES (< 0.0.4) CORRECTLY
#        lMatch = iXMLContentElement.text.match(/^<cmd>(.*)<\/cmd><dir>(.*)<\/dir>(.*)$/)
#        if (lMatch == nil)
#          logBug "Unable to read #{iXMLContentElement.text}"
#          return [
#            iXMLContentElement.text,
#            '',
#            false
#          ]
#        else
#          return [
#            lMatch[1],
#            lMatch[2],
#            !lMatch[3].empty?
#          ]
#        end
        return [
          iXMLContentElement.elements['cmd'].text,
          iXMLContentElement.elements['dir'].text,
          (iXMLContentElement.elements['terminal'] != nil)
        ]
      end

      # Get the icon best reflecting the content.
      #
      # Parameters:
      # * *iContent* (_Object_): The content to read from
      # Return:
      # * <em>Wx::Bitmap</em>: The corresponding icon (can be nil if none)
      def getDefaultIconFromContent(iContent)
        rIcon = nil

        # Get the icon from the executable
        # First get the executable name
        lExeFileName = nil
        if (iContent[0].include?(' '))
          lMatch = iContent[0].match(/^([^ ]*) .*$/)
          if (lMatch == nil)
            logBug "Invalid command parsed: #{iContent[0]}"
          else
            lExeFileName = lMatch[1]
          end
        else
          lExeFileName = iContent[0]
        end
        if (lExeFileName != nil)
          if (File.exists?(lExeFileName))
            # Get icon from it
            rIcon = getBitmapFromFile(lExeFileName)
          else
            logErr "File #{lExeFileName} does not exist. Can't get icon from it."
          end
        end

        return rIcon
      end

    end

  end

end
