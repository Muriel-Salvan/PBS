#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rexml/document'

module PBS

  module Exports

    class XML

      # Execute the export
      #
      # Parameters:
      # * *iController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(iController, iParentWindow)
        # Display Save directory Dialog
        showModal(Wx::FileDialog, iParentWindow,
          :message => 'Save file',
          :style => Wx::FD_SAVE|Wx::FD_OVERWRITE_PROMPT,
          :wildcard => 'XML file (*.xml)|*.xml'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            File.open(iDialog.path, 'w') do |oFile|
              lXML = REXML::Document.new
              lXML << REXML::XMLDecl.new
              lRootElement = lXML.add_element('root')
              lTagsElement = lRootElement.add_element('tags')
              # First, create the Tags hierarchy
              addTagChildrenInXMLElement(iController.RootTag, lTagsElement)
              # Then export Shortcuts
              lShortcutsElement = lRootElement.add_element('shortcuts')
              iController.ShortcutsList.each do |iShortcut|
                addShortcutInXMLElement(iShortcut, lShortcutsElement)
              end
              lXML.write(oFile)
            end
          end
        end
      end

      # Add a Tag's children in an XML element
      #
      # Parameters:
      # * *iTag* (_Tag_): Tag to map in the given XML element
      # * *oXMLElement* (<em>REXML::Element</em>): XML element
      def addTagChildrenInXMLElement(iTag, oXMLElement)
        iTag.Children.each do |iChildTag|
          # Create an element for the child Tag
          lTagXMLElement = oXMLElement.add_element(
            'tag',
            {
              'id' => iChildTag.object_id.to_s,
              'name' => iChildTag.Name,
              'icon' => getBitmapStandardURI(iChildTag.Icon)
            }
          )
          lChildrenXMLElement = lTagXMLElement.add_element('children')
          addTagChildrenInXMLElement(iChildTag, lChildrenXMLElement)
        end
      end

      # Add a Shortcut in an XML element
      #
      # Parameters:
      # * *iShortcut* (_Shortcut_): The Shortcut to export
      # * *oXMLElement* (<em>REXML::Element</em>): XML element
      def addShortcutInXMLElement(iShortcut, oXMLElement)
        # Here we set the metadata
        lShortcutElement = oXMLElement.add_element(
          'shortcut',
          {
            'type' => iShortcut.Type.pluginDescription[:PluginName],
            'name' => iShortcut.Metadata['title'],
            'icon' => getBitmapStandardURI(iShortcut.Metadata['icon'])
          }
        )
        # Here we set the content as simple text of content element.
        lContentElement = lShortcutElement.add_element('content')
        iShortcut.Type.getContentAsXMLText(iShortcut.Content, lContentElement)
        # Now we set the Tags
        lTagsElement = lShortcutElement.add_element('tags')
        iShortcut.Tags.each do |iTag, iNil|
          lTagsElement.add_element(
            'tag',
            {
              'id' => iTag.object_id.to_s
            }
          )
        end
      end

    end

  end

end