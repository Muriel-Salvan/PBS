#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Define objects used for clipboard and drag'n'drop operations

module PBS

  module Tools

    # Object that is used with the clipboard
    class DataObjectSelection < Wx::DataObject

      # constructor
      def initialize
        super
        @Data = nil
        @DataAsText = nil
      end

      # Set the data to send to the clipboard
      #
      # Parameters::
      # * *iCopyType* (_Integer_): Type of the copy (Wx::ID_COPY/Wx::ID_CUT)
      # * *iCopyID* (_Integer_): ID of the copy
      # * *iSerializedSelection* (<em>MultipleSelection::Serialized</em>): The serialized selection (can be nil for acks)
      def setData(iCopyType, iCopyID, iSerializedSelection)
        @Data = Marshal.dump( [ iCopyType, iCopyID, iSerializedSelection ] )
        if (iSerializedSelection == nil)
          @DataAsText = nil
        else
          @DataAsText = iSerializedSelection.getSingleContent
        end
      end

      # Get the data from the clipboard
      #
      # Return::
      # * _Integer_: Type of the copy (Wx::ID_COPY/Wx::ID_CUT)
      # * _Integer_: ID of the copy
      # * <em>MultipleSelection::Serialized</em>: The serialized selection (can be nil for acks)
      def getData
        return Marshal.load(@Data)
      end

      # Get the data format
      #
      # Return::
      # * <em>Wx::DataFormat</em>: The data format
      def self.getDataFormat
        if (!defined?(@@PBS_CLIPBOARD_DATA_FORMAT))
          # Custom format, that ensures only PBS will use this clipboard data
          @@PBS_CLIPBOARD_DATA_FORMAT = Wx::DataFormat.new('PBSClipboardDataFormat')
        end
        return @@PBS_CLIPBOARD_DATA_FORMAT
      end

      # Get the list of all supported formats.
      #
      # Parameters::
      # * *iDirection* (_Object_): ? Not documented
      # Return::
      # * <em>list<Wx::DataFormat></em>: List of supported data formats
      def get_all_formats(iDirection)
        if (@DataAsText != nil)
          return [ DataObjectSelection.getDataFormat, Wx::DF_TEXT ]
        else
          return [ DataObjectSelection.getDataFormat ]
        end
      end

      # Method used by the clipboard itself to fill data
      #
      # Parameters::
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # * *iData* (_String_): The data
      def set_data(iFormat, iData)
        case iFormat
        when Wx::DF_TEXT
          @DataAsText = iData
        when DataObjectSelection.getDataFormat
          @Data = iData
        else
          log_bug "Set unknown format: #{iFormat}"
        end
      end

      # Method used by Wxruby to retrieve the data
      #
      # Parameters::
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # Return::
      # * _String_: The data
      def get_data_here(iFormat)
        rData = nil

        case iFormat
        when Wx::DF_TEXT
          rData = @DataAsText
        when DataObjectSelection.getDataFormat
          rData = @Data
        else
          log_bug "Asked unknown format: #{iFormat}"
        end

        return rData
      end

      # Redefine this method to be used with Wx::DataObjectComposite that requires it
      #
      # Parameters::
      # * *iFormat* (<em>Wx::DataFormat</em>): The format used
      # Return::
      # * _Integer_: The data size
      def get_data_size(iFormat)
        rDataSize = 0

        case iFormat
        when Wx::DF_TEXT
          # Add 1, otherwise it replaces last character with \0x00
          rDataSize = @DataAsText.length + 1
        when DataObjectSelection.getDataFormat
          rDataSize = @Data.length
        else
          log_bug "Asked unknown format for size: #{iFormat}"
        end

        return rDataSize
      end

    end

    # Class that is used for drag'n'drop
    class SelectionDropSource < Wx::DropSource

      # Constructor
      #
      # Parameters::
      # * *iDragImage* (<em>Wx::DragImage</em>): The drag image to display
      # * *iWindow* (<em>Wx::Window</em>): The window initiating the Drag'n'Drop
      # * *iSelection* (_MultipleSelection_): The selection being dragged
      # * *iController* (_Controller_): The data model controller
      def initialize(iDragImage, iWindow, iSelection, iController)
        super(iWindow)

        @DragImage = iDragImage
        @Selection = iSelection
        @Controller = iController
        @OldEffect = nil

        # Create the serialized data
        lData = Tools::DataObjectSelection.new
        lData.setData(Wx::ID_CUT, @Controller.getNewCopyID, @Selection.getSerializedSelection)

        # Set the DropSource internal data
        self.data = lData
      end

      # Change appearance.
      #
      # Parameters::
      # * *iEffect* (_Integer_): The effect to implement. One of DragCopy, DragMove, DragLink and DragNone.
      # Return::
      # * _Boolean_: false if you want default feedback, or true if you implement your own feedback. The return values is ignored under GTK.
      def give_feedback(iEffect)
        # Drag the image
        @DragImage.move(Wx::get_mouse_position)
        # Change icons of items to be moved if the sugggested result (Move/Copy) has changed
        if (iEffect != @OldEffect)
          case iEffect
          when Wx::DRAG_MOVE
            @Controller.notifyObjectsDragMove(@Selection)
          when Wx::DRAG_COPY
            @Controller.notifyObjectsDragCopy(@Selection)
          else
            @Controller.notifyObjectsDragNone(@Selection)
          end
          @OldEffect = iEffect
        end
        # Default feedback is ok
        return false
      end

    end

  end

end
