#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Shortcut
  class Shortcut

    # The type
    #   Object
    attr_reader :Type

    # The set of tags this Shortcut belongs to
    #   map< Tag, nil >
    attr_reader :Tags

    # The content, type dependent
    #   Object
    attr_reader :Content

    # The metadata, used by integration plugins. It is a map of values (see this as properties)
    #   map< String, Object >
    attr_reader :Metadata

    # Constructor
    # This constructor should be used ONLY by UOA_* classes to ensure proper Undo/Redo management.
    #
    # Parameters::
    # * *iType* (_Type_): The type
    # * *iContent* (_Object_): The content
    # * *iMetadata* (<em>map<String,Object></em>): The metadata
    # * *iTags* (<em>map<Tag,nil></em>): The Tags
    def initialize(iType, iContent, iMetadata, iTags)
      @Type = iType
      @Content = iContent
      @Metadata = iMetadata
      @Tags = iTags
    end

    # Get the summary of its content.
    # This could be used in tool tips for example.
    #
    # Return::
    # * _String_: The content's summary
    def getContentSummary
      @Type.getContentSummary(@Content)
    end

    # Dump the Shortcut's info in a String
    #
    # Parameters::
    # * *iPrefix* (_String_): The prefix to append to the strings [optional = '']
    # Return::
    # * _String_: The dump
    def dump(iPrefix)
      rDump = ''

      rDump += "#{iPrefix}+-Type: #{@Type.inspect}\n"
      rDump += "#{iPrefix}+-Content: #{@Content.inspect}\n"
      rDump += "#{iPrefix}+-Metadata:\n"
      @Metadata.each do |iKey, iValue|
        rDump += "#{iPrefix}| +-#{iKey}: #{iValue.inspect}\n"
      end
      rDump += "#{iPrefix}+-Tags:\n"
      @Tags.each do |iTag, iNil|
        rDump += "#{iPrefix}  +-#{iTag.Name} (@#{iTag.object_id})\n"
      end

      return rDump
    end

    # Method that runs the Shortcut
    def run
      @Type.run(@Content)
    end

    # !!! Following methods have to be used ONLY by UAO_* classes.
    # !!! This is the only way to ensure that Undo/Redo management will behave correctly.

    # Set the content of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters::
    # * *iNewContent* (_Object_): The new content
    def _UNDO_setContent(iNewContent)
      @Content = iNewContent
    end

    # Set the metadata of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters::
    # * *iNewMetadata* (<em>map<String,Object></em>): The new metadata
    def _UNDO_setMetadata(iNewMetadata)
      @Metadata = iNewMetadata
    end

    # Set the tags of the Shortcut. This is used only for Undo purposes.
    # !!! This method has to be called ONLY inside protected AtomicOperation classes
    #
    # Parameters::
    # * *iNewTags* (<em>map<Tag,nil></em>): The new tags
    def _UNDO_setTags(iNewTags)
      # Remove Tags that are not part of the new list
      @Tags.delete_if do |iTag, iNil|
        !iNewTags.has_key?(iTag)
      end
      # Add Tags that are not part of the current list
      iNewTags.each do |iTag, iNil|
        @Tags[iTag] = nil
      end
    end

  end
  
end
