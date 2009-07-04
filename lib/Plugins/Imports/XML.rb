#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rexml/document'

module PBS

  module Imports

    class XML

      include Tools

      # Execute the import
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParentWindow* (<em>Wx::Window</em>): The parent window to display the dialog box (can be nil)
      def execute(ioController, iParentWindow)
        # Display Open dialog
        showModal(Wx::FileDialog, iParentWindow,
          :message => 'Open XML file',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'XML files (*.xml)|*.xml'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            ioController.undoableOperation("Import XML file #{File.basename(iDialog.path)[0..-5]}") do
              if (ioController.checkSavedWorkAndScratch(iParentWindow))
                importXMLData(ioController, iDialog.path)
              end
            end
          end
        end
      end

      # Import XML data from a file
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iFileName* (_String_): File name
      def importXMLData(ioController, iFileName)
        File.open(iFileName, 'r') do |iFile|
          lXML = REXML::Document.new(iFile)
          lTagsElement = lXML.root.elements['tags']
          if (lTagsElement == nil)
            logErr "XML file does not have a \"tags\" tag. Invalid XML file, ignoring it."
          else
            # Keep a correspondance between the IDs given to Tags and the real Tags associated to it
            # map< Integer, Tag >
            lIDsToTags = {}
            importXMLTags(ioController, lTagsElement, ioController.RootTag, lIDsToTags)
            # And now the Shortcuts
            lShortcutsElement = lXML.root.elements['shortcuts']
            if (lShortcutsElement == nil)
              logErr "XML file does not have a \"shortcuts\" tag. Invalid XML file, ignoring it."
            else
              lShortcutsElement.elements.each do |iShortcutElement|
                lTypeName = iShortcutElement.attributes['type']
                # The icon
                lIconBitmap = createBitmapFromStandardURI(iShortcutElement.attributes['icon'])
                # The content
                lContent = ioController.TypesPlugins[lTypeName][:plugin].createContentFromXMLText(iShortcutElement.elements['content'])
                # The Tags
                lTags = {}
                iShortcutElement.elements['tags'].elements.each do |iTagElement|
                  lTag = lIDsToTags[iTagElement.attributes['id'].to_i]
                  if (lTag == nil)
                    logBug "Shortcut #{iShortcutElement.attributes['name']} was referencing Tag of ID #{iTagElement.attributes['id'].to_i}, but no Tag was registered under this ID in the XML file. Ignoring this Tag."
                  else
                    lTags[lTag] = nil
                  end
                end
                # Create it
                ioController.createShortcut(
                  lTypeName,
                  lContent,
                  {
                    'title' => iShortcutElement.attributes['name'],
                    'icon' => lIconBitmap
                  },
                  lTags
                )
              end
            end
          end
        end
      end

      # Import Tags encoded in an XML tag
      #
      # Parameters:
      # * *ioController* (_Controller_): The controller
      # * *iTagsElement* (<em>REXML::Element</em>): XML element containing every <tag> XML tag
      # * *oParentTag* (_Tag_): The Tag in which we will instantiate the found Tags
      # * *oIDsToTags* (<em>map<Integer,Tag></em>): Correspondance between internal IDs used in the XML fileand the real Tags instantiated
      def importXMLTags(ioController, iTagsElement, oParentTag, oIDsToTags)
        iTagsElement.elements.each do |iTagElement|
          lIconBitmap = createBitmapFromStandardURI(iTagElement.attributes['icon'])
          # lIconBitmap can be nil
          lNewTag = ioController.createTag(oParentTag, iTagElement.attributes['name'], lIconBitmap)
          # Register it
          oIDsToTags[iTagElement.attributes['id'].to_i] = lNewTag
          # Parse children
          importXMLTags(ioController, iTagElement.elements['children'], lNewTag, oIDsToTags)
        end
      end

    end

  end

end