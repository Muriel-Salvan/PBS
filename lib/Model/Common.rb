#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# To serialize a bitmap, we need a temporary file
require 'tmpdir'

# It is impossible to marshal_load a Wx::Bitmap using load_file, as the C-type is checked during load_file call and the Marshaller does not create exactly the same C-type between 2 executions.
# Therefore we have 2 alternatives:
# 1. give an external way (no more marshal_dump/marshal_load) to serialize a bitmap with load_file (the one we are doing here)
# 2. don't use load_file to get the content back during marshal_load. Unfortunately Wx::Bitmap does not have any other method (or maybe using Wx::Image ?).
# TODO (WxRuby): Implement Wx::Bitmap::marshal_dump and Wx::Bitmap::marshal_load
# TODO (WxRuby): Implement Wx::Bitmap::<=> and Wx::Bitmap.eql? and remove current home-made implementation
module Wx

  class Bitmap

    # Get the serialized content.
    # Equivalent to marshal_dump (could be renamed if only load_file could work)
    #
    # Return:
    # * _String_: The serialized content
    def getSerialized
      rData = ''

      # Require a temporary file
      lFileName = "#{Dir.tmpdir}/#{object_id}.png"
      if (save_file(lFileName, Wx::BITMAP_TYPE_PNG))
        File.open(lFileName, 'rb') do |iFile|
          rData = iFile.read
        end
        File.unlink(lFileName)
      else
        puts "!!! Error while loading data from temporary file: #{lFileName}."
      end

      return rData
    end

    # Set the content based on a serialized one
    # Equivalent to marshal_load (could be renamed if only load_file could work)
    #
    # Parameters:
    # * *iData* (_String_): The serialized content
    def setSerialized(iData)
      # Require a temporary file
      lFileName = "#{Dir.tmpdir}/#{object_id}.png"
      File.open(lFileName, 'wb') do |oFile|
        oFile.write(iData)
      end
      if (load_file(lFileName, Wx::BITMAP_TYPE_PNG))
        File.unlink(lFileName)
      else
        puts "!!! Error while loading data from temporary file: #{lFileName}."
      end
    end

    # Compares 2 different bitmaps
    # It stores results in a cache to speed up comparisons
    #
    # Parameters:
    # * *iOtherBitmap* (<em>Wx::Bitmap</em>): The other bitmap to compare
    # Return:
    # * _Integer_: The comparison (self - iOtherBitmap)
    def <=>(iOtherBitmap)
      if (!defined?(@CacheDataCompare))
        # The cache: For each bitmap's object id, the comparison
        # map< Integer, Integer >
        @CacheDataCompare = {}
      end
      if (@CacheDataCompare[iOtherBitmap.object_id] == nil)
        # Perform the comparison of the data
        @CacheDataCompare[iOtherBitmap.object_id] = self.convert_to_image.data.<=>(iOtherBitmap.convert_to_image.data)
      end

      return @CacheDataCompare[iOtherBitmap.object_id]
    end

    # Is the given bitmap equal to ourselves ?
    #
    # Parameters:
    # * *iOtherBitmap* (<em>Wx::Bitmap</em>): The other bitmap to compare
    # Return:
    # * _Boolean_: Is the given bitmap equal to ourselves ?
    def ==(iOtherBitmap)
      return ((self.object_id == iOtherBitmap.object_id) or
              ((self.class == iOtherBitmap.class) and
               (self.<=>(iOtherBitmap) == 0)))
    end

  end

end
