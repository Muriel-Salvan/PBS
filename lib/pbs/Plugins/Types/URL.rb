#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'nokogiri'

module PBS

  module Types

    class URL

      # Cache of Favicons per HTML URL
      # map< String, Wx::Bitmap >
      @@FaviconsCache = {}

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
        lError = $rUtilAnts_Platform_Info.launchURL(iContent)
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
        lURLMatch = iContent.match(/^(ftp|ftps|http|https):\/\/(.*)$/)
        if (lURLMatch == nil)
          logErr "Could not identify a valid URL: #{iContent}"
        else
          # Check the cache first
          if (!@@FaviconsCache.has_key?(iContent))
            # Fill the cache
            lIcon, lError = getFavicon(iContent)
            if (lIcon == nil)
              logErr "Could not get favicon from #{iContent}: #{lError}."
            end
            @@FaviconsCache[iContent] = lIcon
          end
          rIcon = @@FaviconsCache[iContent]
        end

        return rIcon
      end

      private

      # Get the favicon associated to a URL
      #
      # Parameters:
      # * *iURL* (_String_): The HTML URL
      # Return:
      # * <em>Wx::Bitmap</em>: The favicon, or nil if none
      # * _Exception_: Exception, or nil if success
      def getFavicon(iURL)
        rIcon = nil
        rError = nil

        lURLMatch = iURL.match(/^(ftp|ftps|http|https):\/\/([^\/]*)\/(.*)$/)
        if (lURLMatch == nil)
          lURLMatch = iURL.match(/^(ftp|ftps|http|https):\/\/(.*)$/)
        end
        if (lURLMatch == nil)
          logErr "Could not identify a valid URL: #{iURL}"
        else
          lURLProtocol, lURLServer, lURLPath = lURLMatch[1..3]
          lURLRoot = "#{lURLProtocol}://#{lURLServer}"
          # Get the HTML content
          lHTMLContent, rError = getURLContent(iURL) do |iContent|
            return iContent, nil
          end
          lHTMLDoc = Nokogiri::HTML(lHTMLContent)
          # Try the rel="icon" and rel="shortcut icon" attributes
          (lHTMLDoc.xpath('//head/link[@rel="icon"]') +
           lHTMLDoc.xpath('//head/link[@rel="shortcut icon"]') +
           lHTMLDoc.xpath('//head/link[@rel="ICON"]') +
           lHTMLDoc.xpath('//head/link[@rel="SHORTCUT ICON"]')).each do |iLinkElement|
            # Found the Favicon from the web page
            lFaviconURL = iLinkElement.attributes['href'].to_s
            # Check if the URL is not a relative path to the current root
            lFaviconURLMatch = lFaviconURL.match(/^(ftp|ftps|http|https):\/\/(.*)$/)
            if (lFaviconURLMatch == nil)
              # It is a relative path
              if (lFaviconURL[0..0] == '/')
                lFaviconURL = "#{lURLRoot}#{lFaviconURL}"
              else
                lFaviconURL = "#{lURLRoot}/#{File.dirname(lURLPath)}/#{lFaviconURL}"
              end
            end
            logDebug "Found Favicon from website in URL #{lFaviconURL}"
            # Some websites store GIF, PNG or JPG files under extension .ico (http://xmlsoft.org/favicon.ico or http://www.gnu.org/favicon.ico)
            if (File.extname(lFaviconURL).upcase == '.ICO')
              rIcon, rError = getBitmapFromURL(lFaviconURL, nil, [ Wx::BITMAP_TYPE_ICO, Wx::BITMAP_TYPE_GIF, Wx::BITMAP_TYPE_PNG, Wx::BITMAP_TYPE_JPEG ])
            else
              rIcon, rError = getBitmapFromURL(lFaviconURL)
            end
            if (rIcon == nil)
              logErr "Unable to get Favicon referenced in URL #{iURL} (#{lFaviconURL}): #{rError}"
            else
              break
            end
          end
          if (rIcon == nil)
            # Now we try a worse attempt: try at the root, files named favicon.ico/png/gif
            # Try possible extensions
            [ 'ico', 'png', 'gif' ].each do |iExt|
              lFaviconURL = "#{lURLRoot}/favicon.#{iExt}"
              # Some websites store GIF, PNG or JPG files under extension .ico (http://xmlsoft.org/favicon.ico or http://www.gnu.org/favicon.ico)
              if (iExt == 'ico')
                rIcon, rError = getBitmapFromURL(lFaviconURL, nil, [ Wx::BITMAP_TYPE_ICO, Wx::BITMAP_TYPE_GIF, Wx::BITMAP_TYPE_PNG, Wx::BITMAP_TYPE_JPEG ])
              else
                rIcon, rError = getBitmapFromURL(lFaviconURL)
              end
              if (rIcon != nil)
                break
              end
            end
          end
        end

        return rIcon, rError
      end

    end

  end

end
