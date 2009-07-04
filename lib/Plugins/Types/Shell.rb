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

        # Constructor
        #
        # Parameters:
        # * *iParent* (_Window_): The parent window
        def initialize(iParent)
          super(iParent)

          # Create all components
          lSTCmd = Wx::StaticText.new(self, Wx::ID_ANY, 'Shell command')
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
          lMainSizer.add_item(@TCCmd, :flag => Wx::GROW, :proportion => 0)
          lMainSizer.add_item([0,8], :proportion => 0)
          lMainSizer.add_item(lSTDir, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
          lMainSizer.add_item(@TCDir, :flag => Wx::GROW, :proportion => 0)
          lMainSizer.add_item([0,8], :proportion => 0)
          lMainSizer.add_item(@CBTerminal, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
          lMainSizer.add_item([0,0], :proportion => 1)
          self.sizer = lMainSizer
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
        $PBS_Platform.execShellCmdNoWait(lCmd, lInTerminal)
        # Change back the current directory
        if (lOldDir != nil)
          Dir.chdir(lOldDir)
        end
      end

      # Get the content as an XML text.
      # Returned text can also contain XML tags, as it will be inserted directly as an XML text of an XML tag.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # Return:
      # * _String_: The XML text
      def getContentAsXMLText(iContent)
        rText = "<cmd>#{iContent[0]}</cmd><dir>#{iContent[1]}</dir>"

        if (iContent[2])
          rText += '<terminal/>'
        end

        return rText
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

    end

  end

end
