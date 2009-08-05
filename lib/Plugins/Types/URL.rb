#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Types

    class URL

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
          lSTURL = Wx::StaticText.new(self, Wx::ID_ANY, 'URL')
          @TCURL = Wx::TextCtrl.new(self)
          @TCURL.min_size = [300, @TCURL.min_size.height]

          # Put them in sizers
          lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
          lMainSizer.add_item([0,0], :proportion => 1)
          lMainSizer.add_item(lSTURL, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
          lMainSizer.add_item(@TCURL, :flag => Wx::GROW, :proportion => 0)
          lMainSizer.add_item([0,0], :proportion => 1)
          self.sizer = lMainSizer
        end

        # Get the content from the controls
        #
        # Return:
        # * _Object_: The corresponding content, which will be associated to a shortcut
        def getData
          return @TCURL.value
        end

        # Set the Panel's contents based on a given content
        #
        # Parameters:
        # * *iContent* (_Object_): The content containing values to put in the panel
        def setData(iContent)
          @TCURL.value = iContent
        end

      end

      # Create an empty content.
      # This is used for putting default values in the NewShortcut dialog.
      #
      # Return:
      # * _Object_: The default content
      def createEmptyContent
        return 'http://www.google.com'
      end

      # Get a simple summary of a given content created by this Type.
      # This could be used in tool tips for example.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # Return:
      # * _String_: The content's summary
      def getContentSummary(iContent)
        return iContent
      end

      # Run a given content
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      def run(iContent)
        lError = $PBS_Platform.launchURL(iContent)
        if (lError != nil)
          logErr lError
        end
      end

      # Fill a given XML element with a content.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # * *oXMLContentElement* (<em>REXML::Element</em>): The XML element to fill with the data
      def getContentAsXMLText(iContent, oXMLContentElement)
        oXMLContentElement.text = iContent
      end

      # Create a content from an XML text.
      # The XML text has been created by getContentAsXMLText.
      #
      # Parameters:
      # * *iXMLContentElement* (<em>REXML::Element</em>): The XML element
      # Return:
      # * _Object_: Content created based on this XML element
      def createContentFromXMLText(iXMLContentElement)
        return iXMLContentElement.text
      end

      # Get the icon best reflecting the content.
      #
      # Parameters:
      # * *iContent* (_Object_): The content to read from
      # Return:
      # * <em>Wx::Bitmap</em>: The corresponding icon (can be nil if none)
      def getDefaultIconFromContent(iContent)
        rIcon = nil

        # Get the favicon from the URL
        lURLMatch = iContent.match(/^(ftp|ftps|http|https):\/\/([^\/]*)$/)
        if (lURLMatch == nil)
          lURLMatch = iContent.match(/^(ftp|ftps|http|https):\/\/([^\/]*)\/(.*)$/)
        end
        if (lURLMatch == nil)
          logErr "Unable to get favicon from URL #{iContent}"
        else
          lFaviconURL = "#{lURLMatch[1]}://#{lURLMatch[2]}/favicon.ico"
          rIcon = getBitmapFromFile(lFaviconURL)
          if (rIcon == nil)
            logErr "Could not get favicon from #{lFaviconURL}"
          end
        end

        return rIcon
      end

    end

  end

end
