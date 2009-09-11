#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Those 3 requires are needed to download temporary favicons
require 'tmpdir'
require 'net/http'
require 'net/ftp'

module PBS

  # Define general constants
  ID_TAG = 0
  ID_SHORTCUT = 1

  # This module define methods that are useful to several functions in PBS, but are not GUI related.
  # They could be used in a command-line mode.
  # No reference to Wx should present in here
  module Tools

    # Map that gives equivalents of accent characters.
    # This is used to compare strings without accents
    # map< String,
    STR_ACCENTS_MAPPING = {
      'A' => [192,193,194,195,196,197].pack('U*'),
      'a' => [224,225,226,227,228,229,230].pack('U*'),
      'AE' => [306].pack('U*'),
      'ae' => [346].pack('U*'),
      'C' => [199].pack('U*'),
      'c' => [231].pack('U*'),
      'E' => [200,201,202,203].pack('U*'),
      'e' => [232,233,234,235].pack('U*'),
      'I' => [314,315,316,317].pack('U*'),
      'i' => [354,355,356,357].pack('U*'),
      'N' => [321].pack('U*'),
      'n' => [361].pack('U*'),
      'O' => [210,211,212,213,214,216].pack('U*'),
      'o' => [242,243,244,245,246,248].pack('U*'),
      'OE' => [188].pack('U*'),
      'oe' => [189].pack('U*'),
      'U' => [331,332,333,334].pack('U*'),
      'u' => [371,372,373,374].pack('U*'),
      'Y' => [335].pack('U*'),
      'y' => [375,377].pack('U*')
    }

    # Get a bitmap from a file among the Graphics directory
    # This method is protected against missing files.
    # This is typically used to load icons from constants during the require period
    #
    # Parameters:
    # * *iFileSubName* (_String_): File path, relative to the Graphics directory
    # Return:
    # * <em>Wx::Bitmap</em>: The corresponding bitmap
    def getGraphic(iFileSubName)
      rBitmap, lError = getBitmapFromURL("#{$PBS_GraphicsDir}/#{iFileSubName}")

      if (rBitmap == nil)
        # Set the broken image if it exists
        lBrokenFileName = "#{$PBS_GraphicsDir}/Broken.png"
        if (File.exist?(lBrokenFileName))
          logBug "Image #{iFileSubName} does not exist among #{$PBS_GraphicsDir}."
          rBitmap = Wx::Bitmap.new(lBrokenFileName)
        else
          logBug "Images #{iFileSubName} and Broken.png do not exist among #{$PBS_GraphicsDir}."
          rBitmap = Wx::Bitmap.new
        end
      end

      return rBitmap
    end

    # Find an executable file in the system path directories.
    # It uses discrete extensions also, platform specific (for example optional .exe suffix for Windows)
    #
    # Parameters:
    # * *iExeName* (_String_): Name of file to search for
    # Return:
    # * _String_: The real complete file name, or nil if none found.
    def findExeInPath(iExeName)
      rFileName = nil

      $rUtilAnts_Platform_Info.getSystemExePath.each do |iDir|
        # First, check the file itself
        if (File.exists?("#{iDir}/#{iExeName}"))
          # Found
          rFileName = "#{iDir}/#{iExeName}"
        else
          # Check possible extensions
          $rUtilAnts_Platform_Info.getDiscreteExeExtensions.each do |iDiscreteExt|
            if (File.exists?("#{iDir}/#{iExeName}#{iDiscreteExt}"))
              # Found
              rFileName = "#{iDir}/#{iExeName}#{iDiscreteExt}"
              break
            end
          end
        end
        if (rFileName != nil)
          break
        end
      end

      return rFileName
    end

    # Set recursively children of a window as readonly
    #
    # Parameters:
    # * *iWindow* (<em>Wx::Window</em>): The window
    def setChildrenReadOnly(iWindow)
      iWindow.children.each do |iChildWindow|
        # Put here every window class that has to be disabled
        if (iChildWindow.is_a?(Wx::TextCtrl))
          iChildWindow.editable = false
        elsif (iChildWindow.is_a?(Wx::BitmapButton))
          iChildWindow.enable(false)
        elsif (iChildWindow.is_a?(Wx::CheckBox))
          iChildWindow.enable(false)
        end
        setChildrenReadOnly(iChildWindow)
      end
    end

    # Apply bitmap layers based on flags on a given bitmap
    #
    # Parameters:
    # * *ioBitmap* (<em>Wx::Bitmap</em>): The bitmap to modify
    # * *iMasks* (<em>list<Wx::Bitmap></em>): The masks to apply to the bitmap
    def applyBitmapLayers(ioBitmap, iMasks)
      # 1. Create the bitmap that will be used as a mask
      lMaskBitmap = Wx::Bitmap.new(ioBitmap.width, ioBitmap.height, 1)
      lMaskBitmap.draw do |ioMaskDC|
        ioBitmap.draw do |iBitmapDC|
          ioMaskDC.blit(0, 0, ioBitmap.width, ioBitmap.height, iBitmapDC, 0, 0, Wx::SET, true)
        end
      end
      # 2. Remove the mask from the original bitmap
      lNoMaskBitmap = Wx::Bitmap.new(ioBitmap.width, ioBitmap.height, 1)
      lNoMaskBitmap.draw do |ioNoMaskDC|
        ioNoMaskDC.brush = Wx::WHITE_BRUSH
        ioNoMaskDC.pen = Wx::WHITE_PEN
        ioNoMaskDC.draw_rectangle(0, 0, ioBitmap.width, ioBitmap.height)
      end
      ioBitmap.mask = Wx::Mask.new(lNoMaskBitmap)
      # 3. Draw on the original bitmap and its mask
      ioBitmap.draw do |ioDC|
        lMaskBitmap.draw do |ioMaskDC|
          iMasks.each do |iMask|
            mergeBitmapOnDC(ioDC, ioMaskDC, iMask)
          end
        end
      end
      # 4. Set the mask correctly
      ioBitmap.mask = Wx::Mask.new(lMaskBitmap)
    end

    # Create a String converting accents characters to their equivalent without accent.
    #
    # Parameters:
    # * *iString* (_String_): The string to convert
    # Return:
    # * _String_: The converted string
    def convertAccentsString(iString)
      rConverted = iString.clone

      STR_ACCENTS_MAPPING.each do |iReplacement, iAccents|
        rConverted.gsub!(Regexp.new("[#{iAccents}]", nil, 'U'), iReplacement)
      end

      return rConverted
    end

    # Dump a Tag in a string
    #
    # Parameters:
    # * *iTag* (_Tag_): The Tag to dump
    # * *iPrefix* (_String_): Prefix of each dump line [optional = '']
    # * *iLastItem* (_Boolean_): Is this item the last one of the list it belongs to ? [optional = true]
    # Return:
    # * _String_: The tag dumped
    def dumpTag(iTag, iPrefix = '', iLastItem = true)
      rDump = ''

      rDump += "#{iPrefix}+-#{iTag.Name} (@#{iTag.object_id})\n"
      if (iLastItem)
        lChildPrefix = "#{iPrefix}  "
      else
        lChildPrefix = "#{iPrefix}| "
      end
      lIdx = 0
      iTag.Children.each do |iChildTag|
        rDump += dumpTag(iChildTag, lChildPrefix, lIdx == iTag.Children.size - 1)
        lIdx += 1
      end

      return rDump
    end

    # Dump a Shortcuts list
    #
    # Parameters:
    # * *iShortcutsList* (<em>list<Shortcut></em>): The Shortcuts list to dump
    # Return:
    # * _String_: The string of Shortcuts dumped
    def dumpShortcutsList(iShortcutsList)
      rDump = ''

      lIdx = 0
      iShortcutsList.each do |iSC|
        rDump += "+-#{iSC.Metadata['title']} (@#{iSC.object_id})\n"
        lPrefix = nil
        if (lIdx == iShortcutsList.size-1)
          lPrefix = '  '
        else
          lPrefix = '| '
        end
        rDump += iSC.dump(lPrefix)
        lIdx += 1
      end

      return rDump
    end

    # Create a standard URI for a given bitmap
    # If the bitmap is nil, return an empty URI with header.
    #
    # Parameters:
    # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap to encode (can be nil)
    # Return:
    # * _String_: The corresponding URI
    def getBitmapStandardURI(iBitmap)
      rEncodedBitmap = 'data:image/png;base64,'

      if (iBitmap != nil)
        # We encode it in base 64, then remove the \n
        rEncodedBitmap += [ iBitmap.getSerialized ].pack('m').split("\n").join
      end

      return rEncodedBitmap
    end

    # Create a bitmap based on a standard URI
    # The data string can have an empty content (but still a header) to identify a nil bitmap (used to indicate sometimes default bitmaps)
    # Currently it supports only images encoded in Base64 format.
    #
    # Parameters:
    # * *iIconData* (_String_): The icon data
    # Return:
    # * <em>Wx::Bitmap</em>: The corresponding bitmap, or nil otherwise
    def createBitmapFromStandardURI(iIconData)
      rIconBitmap = nil

      # Don't use URL caching for those ones.
      accessFile(iIconData, :LocalFileAccess => true) do |iFileName, iFileBaseName|
        rIconBitmap = Wx::Bitmap.new(iFileName)
      end

      return rIconBitmap
    end

    # Check if we can import a serialized selection (from local or external source) in a given Tag.
    # The algorithm is as follow:
    # 1. Check first if import is possible without questioning unicity constraints:
    # 1.1. If the selection is from an external source (other application through clipboard/drop...):
    # 1.1.1. Ok, go to step 2.
    # 1.2. Else:
    # 1.2.1. If the selection is to be copied (no delete afterwards):
    # 1.2.1.1. If the primary selection contains Shortcuts, and we want to import in the Root Tag:
    # 1.2.1.1.1. Fail (we can't copy Shortcuts already having Tags to remove their Tags afterwards)
    # 1.2.1.2. Else:
    # 1.2.1.2.1. OK, go to step 2.
    # 1.2.2. Else (it is then to be moved):
    # 1.2.2.1. Check that we will not delete what is being imported afterwards:
    # 1.2.2.1.1. If the Tag to import to is part of the selection (primary or secondary):
    # 1.2.2.1.1.1. Fail (we can't move it to itself or one of its sub-Tags)
    # 1.2.2.1.2. Else, if one of the primary selected Tags is a direct sub-Tag of the Tag we import to:
    # 1.2.2.1.2.1. Fail (we can't move to the same place, it is useless)
    # 1.2.2.1.3. Else, if one of the primary selected Shortcuts already belongs to the Tag we import to:
    # 1.2.2.1.3.1. Fail (we can't move to the same place, it is useless)
    # 1.2.2.1.4. Else:
    # 1.2.2.1.4.1. OK, go to step 2.
    # 2. Then, check that importing there does not violate any unicity constraints:
    # 2.1. If the option has been set to reject automatically the operation in case of Shortcuts doublons (SHORTCUTSCONFLICT_CANCEL_ALL):
    # 2.1.1. If at least 1 of the selected Shortcuts (primary and secondary) is in conflict with our Shortcuts:
    # 2.1.1.1. Fail (the operation would have been cancelled anyway due to Shortcuts doublons)
    # 2.2. If the option has been set to reject automatically the operation in case of Tags doublons (TAGSCONFLICT_CANCEL_ALL):
    # 2.2.1. If at least 1 of the primary selected Tags is in conflict with children of the Tag we import to:
    # 2.2.1.1. Fail (the operation would have been cancelled anyway due to Tags doublons)
    #
    # Parameters:
    # * *iController* (_Controller_): The controller
    # * *iSelection* (_MultipleSelection_): The selection in which we paste (nil in case of the Root Tag)
    # * *iCopyType* (_Integer_): The copy type of what is to be pasted (Wx::ID_COPY or Wx::ID_CUT)
    # * *iLocalSelection* (_MultipleSelection_): The local selection that can be pasted if the source data to be copied is us (nil if external application source of data to be pasted)
    # * *iSerializedSelection* (<em>MultipleSelection::Serialized</em>): The serialized selection to be pasted (nil if we don't have the information)
    # Return:
    # * _Boolean_: Can we paste ?
    # * <em>list<String></em>: Reasons why we can't paste (empty in case of success)
    def isPasteAuthorized?(iController, iSelection, iCopyType, iLocalSelection, iSerializedSelection)
      rPasteOK = true
      rError = []

      if ((iSelection == nil) or
          (iSelection.singleTag?))
        # The selection is valid
        if (iSelection == nil)
          lSelectedTag = iController.RootTag
        else
          lSelectedTag = iSelection.SelectedPrimaryTags[0]
        end
        # Here, lSelectedTag contains the Tag in which we import data, possibly the Root Tag.
        # 1. Check first if import is possible without questioning unicity constraints:
        # 1.1. If the selection is from an external source (other application through clipboard/drop...):
        # 1.1.1. Ok, go to step 2.
        # 1.2. Else:
        if (iLocalSelection != nil)
          # 1.2.1. If the selection is to be copied (no delete afterwards):
          if (iCopyType == Wx::ID_COPY)
            # 1.2.1.1. If the primary selection contains Shortcuts, and we want to import in the Root Tag:
            if ((!iLocalSelection.SelectedPrimaryShortcuts.empty?) and
                (lSelectedTag == iController.RootTag))
              # 1.2.1.1.1. Fail (we can't copy Shortcuts already having Tags to remove their Tags afterwards)
              rPasteOK = false
              rError << 'Can\'t copy Shortcuts already having Tags to remove their Tags afterwards'
            end
            # 1.2.1.2. Else:
            # 1.2.1.2.1. OK, go to step 2.
          # 1.2.2. Else (it is then to be moved):
          else
            # 1.2.2.1. Check that we will not delete what is being imported afterwards:
            # 1.2.2.1.1. If the Tag to import to is part of the selection (primary or secondary):
            if (iLocalSelection.tagSelected?(lSelectedTag))
              # 1.2.2.1.1.1. Fail (we can't move it to itself or one of its sub-Tags)
              rPasteOK = false
              rError << "Can't move Tag #{lSelectedTag.Name} in one of its sub-Tags."
            # 1.2.2.1.2. Else, if one of the primary selected Tags is a direct sub-Tag of the Tag we import to:
            else
              # Check that each primary selected Tag is not a direct sub-Tag of lSelectedTag
              lSelectedTag.Children.each do |iChildTag|
                # Check if iChildTag is not selected among primary selection
                iLocalSelection.SelectedPrimaryTags.each do |iTag|
                  if (iTag == iChildTag)
                    # 1.2.2.1.2.1. Fail (we can't move to the same place, it is useless)
                    rPasteOK = false
                    rError << "Tag #{iChildTag.Name} is already a sub-Tag of #{lSelectedTag.Name}."
                    # If we don't want to log more errors, we can uncomment the following
                    #break
                  end
                end
                # If we don't want to log more errors, we can uncomment the following
                #if (!rPasteOK)
                #  break
                #end
              end
              # 1.2.2.1.3. Else, if one of the primary selected Shortcuts already belongs to the Tag we import to:
              if (rPasteOK)
                iLocalSelection.SelectedPrimaryShortcuts.each do |iShortcutInfo|
                  iShortcut, iParentTag = iShortcutInfo
                  if ((lSelectedTag == iController.RootTag) and
                      (iShortcut.Tags.empty?))
                    # 1.2.2.1.3.1. Fail (we can't move to the same place, it is useless)
                    # It already belongs to the Root Tag
                    rPasteOK = false
                    rError << "Shortcut #{iShortcut.Metadata['title']} is already part of the Root Tag."
                    # If we don't want to log more errors, we can uncomment the following
                    #break
                  elsif ((lSelectedTag != iController.RootTag) and
                         (iShortcut.Tags.has_key?(lSelectedTag)))
                    # 1.2.2.1.3.1. Fail (we can't move to the same place, it is useless)
                    rPasteOK = false
                    rError << "Shortcut #{iShortcut.Metadata['title']} is already part of Tag #{lSelectedTag.Name}."
                    # If we don't want to log more errors, we can uncomment the following
                    #break
                  end
                end
              # 1.2.2.1.4. Else:
              # 1.2.2.1.4.1. OK, go to step 2.
              end
            end
          end
        end
        # 2. Then, check that importing there does not violate any unicity constraints:
        # 2.1. If the option has been set to reject automatically the operation in case of Shortcuts doublons (SHORTCUTSCONFLICT_CANCEL_ALL):
        if (iController.Options[:shortcutsConflict] == SHORTCUTSCONFLICT_CANCEL_ALL)
          # 2.1.1. If at least 1 of the selected Shortcuts (primary and secondary) is in conflict with our Shortcuts:
          if (iLocalSelection != nil)
            # Perform the checks on the local selection
            iController.ShortcutsList.each do |iExistingShortcut|
              (iLocalSelection.SelectedPrimaryShortcuts + iLocalSelection.SelectedSecondaryShortcuts).each do |iShortcutInfo|
                iShortcut, iParentTag = iShortcutInfo
                if ((iExistingShortcut.Type == iShortcut.Type) and
                    (iController.shortcutSameAs?(iExistingShortcut, iShortcut.Content, iShortcut.Metadata)))
                  # 2.1.1.1. Fail (the operation would have been cancelled anyway due to Shortcuts doublons)
                  rPasteOK = false
                  rError << "Shortcut #{iShortcut.Metadata['title']} would result in conflict with Shortcut #{iExistingShortcut.Metadata['title']}. You can remove automatic cancellation in the conflicts options."
                  # If we don't want to log more errors, we can uncomment the following
                  #break
                end
              end
              # If we don't want to log more errors, we can uncomment the following
              #if (!rPasteOK)
              #  break
              #end
            end
          elsif (iSerializedSelection != nil)
            # Perform the checks using the serialized selection
            iController.ShortcutsList.each do |iExistingShortcut|
              iSerializedSelection.getSelectedShortcuts.each do |iSerializedShortcut|
                if ((iExistingShortcut.Type.pluginDescription[:PluginName] == iSerializedShortcut.TypePluginName) and
                    (iController.shortcutSameAsSerialized?(iExistingShortcut, iSerializedShortcut.Content, iSerializedShortcut.Metadata)))
                  # 2.1.1.1. Fail (the operation would have been cancelled anyway due to Shortcuts doublons)
                  rPasteOK = false
                  rError << "Shortcut #{iSerializedShortcut.Metadata['title']} would result in conflict with Shortcut #{iExistingShortcut.Metadata['title']}. You can remove automatic cancellation in the conflicts options."
                  # If we don't want to log more errors, we can uncomment the following
                  #break
                end
              end
              # If we don't want to log more errors, we can uncomment the following
              #if (!rPasteOK)
              #  break
              #end
            end
          end
        end
        # 2.2. If the option has been set to reject automatically the operation in case of Tags doublons (TAGSCONFLICT_CANCEL_ALL):
        if ((rPasteOK) and
            (iController.Options[:tagsConflict] == TAGSCONFLICT_CANCEL_ALL))
          # 2.2.1. If at least 1 of the primary selected Tags is in conflict with children of the Tag we import to:
          if (iLocalSelection != nil)
            # Perform the checks on the local selection
            lSelectedTag.Children.each do |iChildTag|
              # Check if iChildTag is in conflict with any primary selected Tag
              iLocalSelection.SelectedPrimaryTags.each do |iTag|
                if (iController.tagSameAs?(iChildTag, iTag.Name, iTag.Icon))
                  # 2.2.1.1. Fail (the operation would have been cancelled anyway due to Tags doublons)
                  rPasteOK = false
                  rError << "Tag #{iTag.Name} would result in conflict with Tag #{iChildTag.Name}. You can remove automatic cancellation in the conflicts options."
                  # If we don't want to log more errors, we can uncomment the following
                  #break
                end
              end
              # If we don't want to log more errors, we can uncomment the following
              #if (!rPasteOK)
              #  break
              #end
            end
          elsif (iSerializedSelection != nil)
            # Perform the checks using the serialized selection
            lSelectedTag.Children.each do |iChildTag|
              # Check if iChildTag is in conflict with any primary selected Tag
              iSerializedSelection.getSelectedPrimaryTags.each do |iSerializedTag|
                if (iController.tagSameAsSerialized?(iChildTag, iSerializedTag.Name, iSerializedTag.Icon))
                  # 2.2.1.1. Fail (the operation would have been cancelled anyway due to Tags doublons)
                  rPasteOK = false
                  rError << "Tag #{iSerializedTag.Name} would result in conflict with Tag #{iChildTag.Name}. You can remove automatic cancellation in the conflicts options."
                  # If we don't want to log more errors, we can uncomment the following
                  #break
                end
              end
              # If we don't want to log more errors, we can uncomment the following
              #if (!rPasteOK)
              #  break
              #end
            end
          end
        end
      else
        rPasteOK = false
        rError << 'Invalid selection. Please select just 1 Tag.'
      end

      return rPasteOK, rError
    end

    # Merge a bitmap on a DeviceContext.
    # It resizes the image to merge to the DC dimensions.
    # It makes a logical or between the 2 masks.
    #
    # Parameters:
    # * *ioDC* (<em>Wx::DC</em>): The device context on which it is merged
    # * *ioMaskDC* (<em>Wx::DC</em>): The device context on which the mask is merged
    # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap to merge
    def mergeBitmapOnDC(ioDC, ioMaskDC, iBitmap)
      lBitmapToMerge = getResizedBitmap(iBitmap, ioDC.size.width, ioDC.size.height)
      # Then we draw on the bitmap itself
      lBitmapToMerge.draw do |iMergeDC|
        ioDC.blit(0, 0, lBitmapToMerge.width, lBitmapToMerge.height, iMergeDC, 0, 0, Wx::COPY, false)
      end
      # And then we draw the mask, once converted to monochrome (painting a coloured bitmap containing Alpha channel to a monochrome DC gives strange results. Bug ?)
      lMonoImageToMerge = lBitmapToMerge.convert_to_image
      lMonoImageToMerge = lMonoImageToMerge.convert_to_mono(lMonoImageToMerge.mask_red, lMonoImageToMerge.mask_green, lMonoImageToMerge.mask_blue)
      Wx::Bitmap.from_image(lMonoImageToMerge).draw do |iMergeDC|
        ioMaskDC.blit(0, 0, lBitmapToMerge.width, lBitmapToMerge.height, iMergeDC, 0, 0, Wx::OR_INVERT, true)
      end
    end

    # Save data in a file
    #
    # Parameters:
    # * *iController* (_Controller_): The controller giving data
    # * *iFileName* (_String_): The file name to save into
    def saveData(iController, iFileName)
      # First serialize our data to store
      lAll = MultipleSelection.new(iController)
      # Select the Root Tag: it selects everything
      lAll.selectTag(iController.RootTag)
      # Serialize the selection and marshal it
      lData = Marshal.dump(lAll.getSerializedSelection)
      # Then write everything in the file
      File.open(iFileName, 'wb') do |iFile|
        iFile.write(lData)
      end
    end

    # Open data from a file
    #
    # Parameters:
    # * *ioController* (_Controller_): The controller that will get data
    # * *iFileName* (_String_): The file name to load from
    def openData(ioController, iFileName)
      # First read the file
      lData = nil
      File.open(iFileName, 'rb') do |iFile|
        lData = iFile.read
      end
      # Unmarshal it and apply it to our controller in the Root Tag.
      Marshal.load(lData).createSerializedTagsShortcuts(ioController, ioController.RootTag, nil)
    end

    # Class used to identify specifically marshallable objects that needed some transformation to become marshallable
    class MarshallableContainer

      # Constants used to identify IDs
      ID_WX_BITMAP = 0

      # The marshallable object
      #   Object
      attr_reader :MarshallableObject

      # The ID
      #   Integer
      attr_reader :ID

      # Constructor
      #
      # Parameters:
      # * *iMarshallableObject* (_Object_): The marshallable object to store
      # * *iID* (_Integer_): ID used to identify this marshallable object type
      def initialize(iMarshallableObject, iID)
        @MarshallableObject = iMarshallableObject
        @ID = iID
      end

    end

    # Get a marshallable version of an object.
    # It calls recursively in case of embedded maps or arrays.
    #
    # Parameters:
    # * *iObject* (_Object_): The source object
    # Return:
    # * _Object_: The object ready to be marshalled
    def getMarshallableObject(iObject)
      rMarshallableObject = iObject

      if (iObject.is_a?(Wx::Bitmap))
        # TODO (WxRuby): Remove this processing once marshal_dump and marshal_load have been implemented in Wx::Bitmap.
        # We convert Bitmaps into Strings manually.
        rMarshallableObject = MarshallableContainer.new(iObject.getSerialized, MarshallableContainer::ID_WX_BITMAP)
      elsif (iObject.is_a?(Hash))
        rMarshallableObject = {}
        iObject.each do |iKey, iValue|
          rMarshallableObject[getMarshallableObject(iKey)] = getMarshallableObject(iValue)
        end
      elsif (iObject.is_a?(Array))
        rMarshallableObject = []
        iObject.each do |iItem|
          rMarshallableObject << getMarshallableObject(iItem)
        end
      end

      return rMarshallableObject
    end

    # Get an object from its marshallable version.
    # It calls recursively in case of embedded maps.
    #
    # Parameters:
    # * *iMarshallableObject* (_Object_): The marshallable object
    # Return:
    # * _Object_: The original object
    def getFromMarshallableObject(iMarshallableObject)
      rObject = iMarshallableObject

      if (iMarshallableObject.is_a?(MarshallableContainer))
        case iMarshallableObject.ID
        when MarshallableContainer::ID_WX_BITMAP
          rObject = Wx::Bitmap.new
          rObject.setSerialized(iMarshallableObject.MarshallableObject)
        else
          logBug "Unknown ID in marshallable object: #{iMarshallableObject.ID}. Returning marshallable object."
        end
      elsif (iMarshallableObject.is_a?(Hash))
        rObject = {}
        iMarshallableObject.each do |iKey, iValue|
          rObject[getFromMarshallableObject(iKey)] = getFromMarshallableObject(iValue)
        end
      elsif (iMarshallableObject.is_a?(Array))
        rObject = []
        iMarshallableObject.each do |iItem|
          rObject << getFromMarshallableObject(iItem)
        end
      end

      return rObject
    end

    # Serialize options
    #
    # Parameters:
    # * *iOptions* (<em>map<Symbol,Object></em>): The options to be serialized
    # Return:
    # * <em>map<Symbol,Object></em>: The serialized options
    def serializeOptions(iOptions)
      lSerializableOptions = {}
      iOptions.each do |iKey, iValue|
        if (iKey == :intPluginsOptions)
          lSerializableOptions[:intPluginsOptions] = {}
          # We have to remove the instances information
          iValue.each do |iPluginID, iPluginsList|
            lSerializableOptions[:intPluginsOptions][iPluginID] = []
            iPluginsList.each do |ioInstantiatedPluginInfo|
              iTagID, iActive, iInstanceOptions, ioInstanceInfo = ioInstantiatedPluginInfo
              lSerializableOptions[:intPluginsOptions][iPluginID] << [ iTagID, iActive, iInstanceOptions ]
            end
          end
        else
          lSerializableOptions[iKey] = iValue
        end
      end
      return getMarshallableObject(lSerializableOptions)
    end

    # Unserialize options
    #
    # Parameters:
    # * *iSerializedOptions* (<em>map<Symbol,Object></em>): The serialized options
    # Return:
    # * <em>map<Symbol,Object></em>: The unserialized options
    def unserializeOptions(iSerializedOptions)
      rOptions = {}

      getFromMarshallableObject(iSerializedOptions).each do |iKey, iValue|
        if (iKey == :intPluginsOptions)
          rOptions[:intPluginsOptions] = {}
          # We have to add empty instances information
          iValue.each do |iPluginID, iPluginsList|
            rOptions[:intPluginsOptions][iPluginID] = []
            iPluginsList.each do |ioInstantiatedPluginInfo|
              iTagID, iActive, iInstanceOptions = ioInstantiatedPluginInfo
              rOptions[:intPluginsOptions][iPluginID] << [ iTagID, iActive, iInstanceOptions, [ nil, nil ] ]
            end
          end
        else
          rOptions[iKey] = iValue
        end
      end
      
      return rOptions
    end

    # Save options data in a file
    #
    # Parameters:
    # * *iOptions* (<em>map<Symbol,Object></em>): The options
    # * *iFileName* (_String_): The file name to save into
    def saveOptionsData(iOptions, iFileName)
      # Serialize the options and marshal it
      lData = Marshal.dump(serializeOptions(iOptions))
      # Then write everything in the file
      begin
        File.open(iFileName, 'wb') do |iFile|
          iFile.write(lData)
        end
      rescue Exception
        logExc $!, "Exception while writing options in file #{iFileName}."
      end
    end

    # Open options data from a file
    #
    # Parameters:
    # * *iFileName* (_String_): The file name to load from
    # Return:
    # * <em>map<Symbol,Object></em>: The options
    def openOptionsData(iFileName)
      # First read the file
      lData = nil
      File.open(iFileName, 'rb') do |iFile|
        lData = iFile.read
      end
      # Unmarshal it
      return unserializeOptions(Marshal.load(lData))
    end

    # Get a new Unique ID for Copy/Paste operations
    #
    # Return:
    # * _Integer_: The unique integer
    def getNewCopyID
      # Use a stupid generator, chances are quite thin to have the same results with a seed based on the current time (how can a user perform a cut simultaneously on 2 applications at the same time ?)
      lNow = Time.now
      srand(lNow.sec*1000000+lNow.usec)
      return rand(Float::MAX)
    end

    # Keys translations
    SPECIALKEYS_STR = {
      Wx::K_BACK => 'Backspace',
      Wx::K_TAB => 'Tab',
      Wx::K_RETURN => 'Enter',
      Wx::K_ESCAPE => 'Escape',
      Wx::K_SPACE => 'Space',
      Wx::K_DELETE => 'Del',
      Wx::K_START => 'Start',
      Wx::K_LBUTTON => 'Mouse Left',
      Wx::K_RBUTTON => 'Mouse Right',
      Wx::K_CANCEL => 'Cancel',
      Wx::K_MBUTTON => 'Mouse Middle',
      Wx::K_CLEAR => 'Clear',
      Wx::K_SHIFT => 'Shift',
      Wx::K_ALT => 'Alt',
      Wx::K_CONTROL => 'Control',
      Wx::K_MENU => 'Menu',
      Wx::K_PAUSE => 'Pause',
      Wx::K_CAPITAL => 'Capital',
      Wx::K_END => 'End',
      Wx::K_HOME => 'Home',
      Wx::K_LEFT => 'Left',
      Wx::K_UP => 'Up',
      Wx::K_RIGHT => 'Right',
      Wx::K_DOWN => 'Down',
      Wx::K_SELECT => 'Select',
      Wx::K_PRINT => 'Print',
      Wx::K_EXECUTE => 'Execute',
      Wx::K_SNAPSHOT => 'Snapshot',
      Wx::K_INSERT => 'Ins',
      Wx::K_HELP => 'Help',
      Wx::K_NUMPAD0 => 'Num 0',
      Wx::K_NUMPAD1 => 'Num 1',
      Wx::K_NUMPAD2 => 'Num 2',
      Wx::K_NUMPAD3 => 'Num 3',
      Wx::K_NUMPAD4 => 'Num 4',
      Wx::K_NUMPAD5 => 'Num 5',
      Wx::K_NUMPAD6 => 'Num 6',
      Wx::K_NUMPAD7 => 'Num 7',
      Wx::K_NUMPAD8 => 'Num 8',
      Wx::K_NUMPAD9 => 'Num 9',
      Wx::K_MULTIPLY => '*',
      Wx::K_ADD => '+',
      Wx::K_SEPARATOR => 'Separator',
      Wx::K_SUBTRACT => '-',
      Wx::K_DECIMAL => '.',
      Wx::K_DIVIDE => '/',
      Wx::K_F1 => 'F1',
      Wx::K_F2 => 'F2',
      Wx::K_F3 => 'F3',
      Wx::K_F4 => 'F4',
      Wx::K_F5 => 'F5',
      Wx::K_F6 => 'F6',
      Wx::K_F7 => 'F7',
      Wx::K_F8 => 'F8',
      Wx::K_F9 => 'F9',
      Wx::K_F10 => 'F10',
      Wx::K_F11 => 'F11',
      Wx::K_F12 => 'F12',
      Wx::K_F13 => 'F13',
      Wx::K_F14 => 'F14',
      Wx::K_F15 => 'F15',
      Wx::K_F16 => 'F16',
      Wx::K_F17 => 'F17',
      Wx::K_F18 => 'F18',
      Wx::K_F19 => 'F19',
      Wx::K_F20 => 'F20',
      Wx::K_F21 => 'F21',
      Wx::K_F22 => 'F22',
      Wx::K_F23 => 'F23',
      Wx::K_F24 => 'F24',
      Wx::K_NUMLOCK => 'Numlock',
      Wx::K_SCROLL => 'Scroll',
      Wx::K_PAGEUP => 'PageUp',
      Wx::K_PAGEDOWN => 'PageDown',
      Wx::K_NUMPAD_SPACE => 'Num Space',
      Wx::K_NUMPAD_TAB => 'Num Tab',
      Wx::K_NUMPAD_ENTER => 'Num Enter',
      Wx::K_NUMPAD_F1 => 'Num F1',
      Wx::K_NUMPAD_F2 => 'Num F2',
      Wx::K_NUMPAD_F3 => 'Num F3',
      Wx::K_NUMPAD_F4 => 'Num F4',
      Wx::K_NUMPAD_HOME => 'Num Home',
      Wx::K_NUMPAD_LEFT => 'Num Left',
      Wx::K_NUMPAD_UP => 'Num Up',
      Wx::K_NUMPAD_RIGHT => 'Num Right',
      Wx::K_NUMPAD_DOWN => 'Num Down',
      Wx::K_NUMPAD_PAGEUP => 'Num PageUp',
      Wx::K_NUMPAD_PAGEDOWN => 'Num PageDown',
      Wx::K_NUMPAD_END => 'Num End',
      Wx::K_NUMPAD_BEGIN => 'Num Begin',
      Wx::K_NUMPAD_INSERT => 'Num Ins',
      Wx::K_NUMPAD_DELETE => 'Num Del',
      Wx::K_NUMPAD_EQUAL => 'Num =',
      Wx::K_NUMPAD_MULTIPLY => 'Num *',
      Wx::K_NUMPAD_ADD => 'Num +',
      Wx::K_NUMPAD_SEPARATOR => 'Num Separator',
      Wx::K_NUMPAD_SUBTRACT => 'Num -',
      Wx::K_NUMPAD_DECIMAL => 'Num .',
      Wx::K_NUMPAD_DIVIDE => 'Num /',
      Wx::K_WINDOWS_LEFT => 'Win Left',
      Wx::K_WINDOWS_RIGHT => 'Win Right',
      Wx::K_WINDOWS_MENU => 'Win Menu',
      Wx::K_COMMAND => 'Command',
      Wx::K_SPECIAL1 => 'Special 1',
      Wx::K_SPECIAL2 => 'Special 2',
      Wx::K_SPECIAL3 => 'Special 3',
      Wx::K_SPECIAL4 => 'Special 4',
      Wx::K_SPECIAL5 => 'Special 5',
      Wx::K_SPECIAL6 => 'Special 6',
      Wx::K_SPECIAL7 => 'Special 7',
      Wx::K_SPECIAL8 => 'Special 8',
      Wx::K_SPECIAL9 => 'Special 9',
      Wx::K_SPECIAL10 => 'Special 10',
      Wx::K_SPECIAL11 => 'Special 11',
      Wx::K_SPECIAL12 => 'Special 12',
      Wx::K_SPECIAL13 => 'Special 13',
      Wx::K_SPECIAL14 => 'Special 14',
      Wx::K_SPECIAL15 => 'Special 15',
      Wx::K_SPECIAL16 => 'Special 16',
      Wx::K_SPECIAL17 => 'Special 17',
      Wx::K_SPECIAL18 => 'Special 18',
      Wx::K_SPECIAL19 => 'Special 19',
      Wx::K_SPECIAL20 => 'Special 20'
    }

    # Get the string representation of an accelerator
    #
    # Parameters:
    # * *iAccelerator* (<em>[Integer,Integer]</em>): The accelerator info
    # Return:
    # * _String_: The visual representation of this accelerator
    def getStringForAccelerator(iAccelerator)
      rResult = ''

      lModifier, lKey = iAccelerator

      # Display modifier
      if (lModifier & Wx::MOD_META != 0)
        rResult << 'Meta+'
      end
      if (lModifier & Wx::MOD_CONTROL != 0)
        rResult << 'Ctrl+'
      end
      if (lModifier & Wx::MOD_ALT != 0)
        rResult << 'Alt+'
      end
      if (lModifier & Wx::MOD_SHIFT != 0)
        rResult << 'Maj+'
      end

      # Display key
      if (SPECIALKEYS_STR[lKey] != nil)
        rResult << SPECIALKEYS_STR[lKey]
      else
        rResult << lKey.chr.upcase
      end

    end

  end

end
