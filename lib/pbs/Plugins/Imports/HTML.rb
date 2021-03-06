#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'nokogiri'

module PBS

  module Imports

    class HTML

      # Here we list all the HTML tags that do not add any indentation in the level of a HTML file.
      # That is HTML tags that will not change the level of links compared with the headers: even if such HTML tags are absent from the file, the resulting Shortcuts/Tags associations would be exactly the same.
      NO_INDENT_HTML_TAGS = [
        'dt', 'p', 'body', 'li', 'head', 'text', 'hr', 'meta', 'title', 'dd',
        'link', 'script', 'small', 'center', 'b', 'br', 'table', 'font', 'tr',
        'td', 'i', 'comment', 'span', '#cdata-section', 'img', 'tbody', 'code',
        'abbr', 'select', 'option', 'style', 'th'
      ]
      # Here we list the HTML tags that add some indentation.
      # This means that when encountering such an HTML tag, we will consider the last HTML header to be the parent Tag of following items (Shortcuts/Tags), unless this HTML tag is closed.
      INDENT_HTML_TAGS = [
        'dl', 'ol', 'ul', 'div', 'pre'
      ]
      # Here we list the HTML header tags.
      HEADER_HTML_TAGS = [
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'h7', 'h8', 'h9'
      ]

      # Execute the import
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParentWindow)
        # Display Open dialog
        showModal(Wx::FileDialog, iParentWindow,
          :message => 'Open HTML file',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'HTML files (*.html;*.htm)|*.html;*.htm'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            ioController.undoableOperation("Import HTML file #{File.basename(iDialog.path)[0..-6]}") do
              if (ioController.checkSavedWorkAndScratch(iParentWindow))
                importHTMLData(ioController, iDialog.path)
              end
            end
          end
        end
      end

      # Import HTML data from a given Nokogiri element
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iElement* (<em>Nokogiri::XML::Element</em>): The element to retrieve data from
      # * *iHeadersStack* (<em>list< [String,Tag] ></em>): The stack of headers encountered and their corresponding Tag
      # * *iTagsDefinedInThisGroup* (<em>list<Tag></em>): List that keeps track of all Tags defined in this group
      # * *iHeaderJustDefined* (_Boolean_): Has last header just been defined ?
      # Return::
      # * <em>list< [String,Tag] ></em>: The headers stack at the end of this method. This is useful in the case we want to just ignore some HTML tags (such as <dt>): the caller will use them at its level also.
      # * <em>list<Tag></em>: List that keeps track of all Tags defined in this group
      # * _Boolean_: Has last header just been defined ?
      def importHTMLDataFromElement(ioController, iElement, iHeadersStack, iTagsDefinedInThisGroup, iHeaderJustDefined)
        # This Tag is the one in which we create the Shortcuts and Tags read from the element.
        rCurrentStack = iHeadersStack.clone
        rTagsDefinedInThisGroup = iTagsDefinedInThisGroup.clone
        rHeaderJustDefined = iHeaderJustDefined

        iElement.children.each do |iChildElement|
          case (iChildElement.name)
          when *HEADER_HTML_TAGS
            # The following Shortcuts belong to this header, seen as a Tag
            # To know which parent Tag is the correct one, we have to check the header level.
            # Find at which place of the stack it would fit
            lIdxStack = 0
            rCurrentStack.each do |iHeaderInfo|
              iHeader, iTag = iHeaderInfo
              # We stop the stack if following headers are:
              # * smaller (greater HTML value), or
              # * equal and the header in the stack has been defined in the same group as we
              # Consider the following HTML example to better understand:
              # h1.A <- Stack=[h1.A]
              # h2.B <- Stack=[h1.A, h2.B]
              # dl
              #   dl
              #     dl
              #     h3.C <- Stack=[h1.A, h2.B, h3.C]
              #     /dl
              #   /dl
              #   dl
              #     h2.D <- Stack=[h1.A, h2.B, h2.D]
              #   /dl
              #   h3.E <- Stack=[h1.A, h2.B, h3.E]
              #   h2.F <- Here, h2 should not replace previous h2 in the stack: Stack=[h1.A, h2.B, h2.F]
              # /dl
              # dl
              #   h2.G <- Stack=[h1.A, h2.B, h2.G]
              #   h2.H <- Here, h2 should replace the second h2 in the stack: Stack=[h1.A, h2.B, h2.H]
              # /li
              if ((iChildElement.name < iHeader) or
                  ((iChildElement.name == iHeader) and
                   (rTagsDefinedInThisGroup.include?(iTag))))
                # We are moving to the position lIdxStack of the stack
                break
              end
              lIdxStack += 1
            end
            # Remove trailing items of the stack
            if (lIdxStack < rCurrentStack.size)
              rCurrentStack = rCurrentStack[0..lIdxStack-1]
            end
            # Get the parent Tag
            lParentTag = rCurrentStack[-1][1]
            # Add it if it does not exist already, and get it back once inserted
            lNewTag = ioController.createTag(lParentTag, iChildElement.content, nil)
            # Add ourselves to the stack
            rTagsDefinedInThisGroup << lNewTag
            rCurrentStack << [ iChildElement.name, lNewTag ]
            rHeaderJustDefined = true
          when *NO_INDENT_HTML_TAGS
            # Here, we stay at the same level of Tag, but the content to parse is considered as an XML sub-tag.
            # We just have to get rid of it, as if this tag never existed.
            # To achieve this, we get the remaining Tag from the recursive call as being the next parent one.
            rCurrentStack, rTagsDefinedInThisGroup, rHeaderJustDefined = importHTMLDataFromElement(ioController, iChildElement, rCurrentStack, rTagsDefinedInThisGroup, rHeaderJustDefined)
          when *INDENT_HTML_TAGS
            # We are entering a new level of Tags
            importHTMLDataFromElement(ioController, iChildElement, rCurrentStack, [], false)
            # In the case that the last found header in this group was declared JUST BEFORE this indented block, we assume that it was relevant only for this block, and so we must now remove it from the headers stack.
            # To better understand, consider this example:
            # h1.A
            # ahref MyLink1 <- MyLink1 belongs to h1.A
            # h2.B
            # dl
            #   ahref MyLink2 <- MyLink2 belongs to h2.B
            # /dl
            # ahref MyLink3 <- MyLink3 belongs to h1.A (because h2.B refers to the title of the group MyLink2 belongs to, as it was defined directly before).
            # h2.C
            # ahref MyLink4 <- MyLink4 belongs to h2.C
            # dl
            #   ahref MyLink5 <- MyLink5 belongs to h2.C
            # /dl
            # ahref MyLink6 <- MyLink6 belongs to h2.C (because of the presence of MyLink4, that proves that the group where MyLink5 is defined is not bound to h2.C only).
            if (rHeaderJustDefined)
              rCurrentStack.pop
            end
          when 'a'
            # Check that it is not just an anchor
            if (iChildElement.attributes['href'] != nil)
              lCurrentTag = rCurrentStack[-1][1]
              # We have a Shortcut, belonging to lCurrentTag
              # Check its type if specified (default to URL)
              lTypeName = 'URL'
              lAttrType = iChildElement.attributes['type']
              if (lAttrType != nil)
                lTypeName = lAttrType.to_s
              end
              # Read its content
              # Here we know all types
              lContent = nil
              case lTypeName
              when 'URL'
                lContent = iChildElement.attributes['href'].to_s
              when 'Shell'
                lContent = iChildElement.attributes['href'].to_s
              else
                log_bug "Unknown link type: #{lTypeName}. Ignoring it."
              end
              if (lContent != nil)
                lIconURL = iChildElement.attributes['icon_uri'].to_s
                # TODO: Use lIconURL if lIconData is empty
                lIconData = iChildElement.attributes['icon'].to_s
                lIconBitmap = createBitmapFromStandardURI(lIconData)
                # Get the title
                lTitle = iChildElement.content
                if (lTitle.strip.empty?)
                  lTitle = 'Unnamed Shortcut'
                end
                # Create the new Shortcut
                # Tags
                lNewTags = {}
                # Beware the root Tag
                if (lCurrentTag != ioController.RootTag)
                  lNewTags[lCurrentTag] = nil
                end
                ioController.createShortcut(
                  lTypeName,
                  lContent,
                  {'title' => lTitle, 'icon' => lIconBitmap},
                  lNewTags
                )
              end
              # The last header is not just defined: a shortcut was defined before the next group
              rHeaderJustDefined = false
            end
          else
            log_bug "Unknown Tag: #{iChildElement.name}. Content: #{iChildElement.content}"
          end
        end

        return rCurrentStack, rTagsDefinedInThisGroup, rHeaderJustDefined
      end

      # Import HTML data
      #
      # Parameters::
      # * *ioController* (_Controller_): The data model controller
      # * *iFileName* (_String_): File name
      def importHTMLData(ioController, iFileName)
        File.open(iFileName, 'r') do |iFile|
          lHTMLDoc = Nokogiri::HTML(iFile)
          importHTMLDataFromElement(ioController, lHTMLDoc.root, [ [ 'h0', ioController.RootTag ] ], [], false)
        end
      end

    end

  end

end