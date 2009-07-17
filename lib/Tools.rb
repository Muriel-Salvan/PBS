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

  OS_WINDOWS = 0

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

    # The class that assign dynamically images to a given TreeCtrl items
    class ImageListManager

      # Constructor
      #
      # Parameters:
      # * *ioImageList* (<em>Wx::ImageList</em>): The image list this manager will handle
      # * *iWidth* (_Integer_): The images width
      # * *iHeight* (_Integer_): The images height
      def initialize(ioImageList, iWidth, iHeight)
        @ImageList = ioImageList
        # TODO (WxRuby): Get the size directly from ioImageList (get_size does not work)
        @Width = iWidth
        @Height = iHeight
        # The internal map of image IDs => indexes
        # map< Object, Integer >
        @Id2Idx = {}
      end

      # Get the image index for a given image ID
      #
      # Parameters:
      # * *iID* (_Object_): Id of the image
      # * *CodeBlock*: The code that will be called if the image ID is unknown. This code has to return a Wx::Bitmap object, representing the bitmap for the given image ID.
      def getImageIndex(iID)
        if (@Id2Idx[iID] == nil)
          # Bitmap unknown.
          # First create it.
          lBitmap = yield
          # Then check if we need to resize it
          if ((lBitmap.width != @Width) or
              (lBitmap.height != @Height))
            # We have to resize the bitmap to @Width/@Height
            lBitmap = Wx::Bitmap.from_image(lBitmap.convert_to_image.scale(@Width, @Height))
          end
          # Then add it to the image list, and register it
          @Id2Idx[iID] = @ImageList.add(lBitmap)
        end

        return @Id2Idx[iID]
      end

    end

    # Load a bitmap from a file
    # This method is protected against missing files.
    # This is typically used to load icons from constants during the require period (this is also the reason why it uses logBugBase instead of logBug).
    #
    # Parameters:
    # * *iBitmapSubPath* (_String_): Sub-path from the Graphics directory
    # Return:
    # * <em>Wx::Bitmap</em>: The bitmap
    def self.loadBitmap(iBitmapSubPath)
      rBitmap = nil

      lFileName = "#{$PBS_GraphicsDir}/#{iBitmapSubPath}"
      if (File.exist?(lFileName))
        rBitmap = Wx::Bitmap.new(lFileName)
      else
        # Set the broken image if it exists
        lBrokenFileName = "#{$PBS_GraphicsDir}/Broken.png"
        if (File.exist?(lBrokenFileName))
          logBugBase "Image #{iBitmapSubPath} does not exist among #{$PBS_GraphicsDir}."
          rBitmap = Wx::Bitmap.new(lBrokenFileName)
        else
          logBugBase "Images #{iBitmapSubPath} and Broken.png do not exist among #{$PBS_GraphicsDir}."
          rBitmap = Wx::Bitmap.new
        end
      end

      return rBitmap
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

    # Get the list of local library directories:
    # * From the ext directory
    # * From the ext gems
    # * From declared directories in GEM_PATH
    #
    # Return:
    # * <em>list<String></em>: The list of directories
    def getLocalExternalLibDirs
      rList = []

      # Manually set libs in local PBS installation
      Dir.glob("#{$PBS_ExtDir}/*") do |iDir|
        if ((iDir != "#{$PBS_ExtDir}/gems") and
            (iDir != "#{$PBS_ExtDir}/libs") and
            (File.exists?("#{iDir}/lib")))
          rList << "#{iDir}/lib"
        end
      end
      # Manually set Gems in local PBS installation
      if (File.exists?($PBS_ExtGemsDir))
        Dir.glob("#{$PBS_ExtGemsDir}/gems/*") do |iDir|
          if (File.exists?("#{iDir}/lib"))
            rList << "#{iDir}/lib"
          end
        end
      end
      # Every directory from GEM_PATH if it exists
      # We do so as we don't want to depend on RubyGems.
      if (defined?(Gem))
        Gem.path.each do |iGemDir|
          if (File.exists?("#{iGemDir}/gems"))
            Dir.glob("#{iGemDir}/gems/*") do |iDir|
              if (File.exists?("#{iDir}/lib"))
                rList << "#{iDir}/lib"
              end
            end
          end
        end
      end

      return rList
    end

    # Get the list of local OS library directories (containing DLLs...)
    #
    # Return:
    # * <em>list<String></em>: The list of directories
    def getLocalExternalDLLDirs
      rList = []

      if (File.exists?($PBS_ExtDllsDir))
        Dir.glob("#{$PBS_ExtDllsDir}/**/*") do |iFileName|
          if (File.directory?(iFileName))
            rList << iFileName
          end
        end
      end

      return rList
    end

    # Adds a list of directories to the load path, ensuring no doublons
    #
    # Parameters:
    # *iDirsList* (<em>list<String></em>): The list of directories
    def addToLoadPath(iDirsList)
      $LOAD_PATH.replace(($LOAD_PATH + iDirsList).uniq)
    end

    # Adds a list of directories to the system libraries paths, ensuring no doublons
    #
    # Parameters:
    # *iDirsList* (<em>list<String></em>): The list of directories
    def addToSystemLoadPath(iDirsList)
      $PBS_Platform.setSystemLibsPath(
        ($PBS_Platform.getSystemLibsPath + iDirsList).uniq
      )
    end

    # Ensure that WxRuby is up and running in our environment
    # This method uses sendMsg method to notify the user. This method has to be defined by the caller.
    #
    # Return:
    # * _Boolean_: Is WxRuby loaded ?
    def ensureWxRuby
      rSuccess = true

      begin
        require 'wx'
      rescue Exception
        # Try to check all paths to load for libs
        addToLoadPath(getLocalExternalLibDirs)
        begin
          require 'wx'
        rescue Exception
          rSuccess = false
          # We need to download wxruby gem
          if (ensureRubyGems(false))
            # Now we want to install the Gem
            $PBS_Platform.sendMsg("WxRuby is not part of this PBS installation.\nInstalling WxRuby will begin after this message, and will take around 10 Mb.\nYou will be notified once it is completed.")
            rSuccess = installGem($PBS_ExtGemsDir, 'wxruby --version 2.0.0', nil, false)
            if (rSuccess)
              # Add the path again
              addToLoadPath(getLocalExternalLibDirs)
              begin
                require 'wx'
              rescue Exception
                $PBS_Platform.sendMsg("WxRuby could not be installed (#{$!}).\nPlease install WxRuby manually in PBS local installation, or reinstall PBS completely.")
              end
              $PBS_Platform.sendMsg("WxRuby has been successfully installed.\nPBS will start after this message.")
            else
              $PBS_Platform.sendMsg("WxRuby could not be installed.\nPlease install WxRuby manually in PBS local installation, or reinstall PBS completely.")
            end
          else
            $PBS_Platform.sendMsg("Unable to install RubyGems.\nPlease download WxRuby manually in PBS local installation, or reinstall PBS completely.")
          end
        end
      end

      return rSuccess
    end

    # Ensure RubyGems environment is loaded correctly
    #
    # Parameters:
    # * *iAcceptDialogs* (_Boolean_): Do we accept displaying dialogs ? This is used to indicate that this method is called without wxruby environment set up. [optional = true]
    # Return:
    # * _Boolean_: Is RubyGems loaded ?
    def ensureRubyGems(iAcceptDialogs = true)
      rSuccess = true

      # First ensure that RubyGems is up and running
      # This require is left here, as we don't want to need it if we don't call this method.
      begin
        require 'rubygems'
        require 'rubygems/command'
        require 'rubygems/remote_installer'
        require 'rubygems/gem_commands'
      rescue Exception
        # RubyGems is not installed (or badly installed).
        # Use our own installation of RubyGems
        # First, clean up possible symbols of previous RubyGems installations
        if (Kernel.method_defined?(:require_gem))
          Kernel.send(:remove_method, :require_gem)
        end
        if (Kernel.method_defined?(:gem))
          Kernel.send(:remove_method, :gem)
        end
        if (Object.const_defined?(:Gem))
          Object.send(:remove_const, :Gem)
        end
        # Test if gem_original_require exists
        begin
          gem_original_require
        rescue ArgumentError
          # It exists: reset the alias
          Kernel.send(:remove_method, :require)
          Kernel.module_eval('alias require gem_original_require')
        rescue Exception
          # Nothing to do
        end
        # Add our path to rubygems at the beginning of the load path
        $LOAD_PATH.replace(["#{$PBS_RootDir}/ext/rubygems"] + $LOAD_PATH)
        # Remove any required file from the require cache concerning rubygems
        $".delete_if do |iFileName|
          (iFileName.match(/^rubygems.*$/) != nil)
        end
        begin
          # Now we reload our version of RubyGems
          require 'rubygems'
          require 'rubygems/command'
          require 'rubygems/remote_installer'
          require 'rubygems/gem_commands'
        rescue Exception
          if (iAcceptDialogs)
            logExc $!, 'PBS installation of RubyGems could not get required'
          else
            if ($PBS_ScreenOutputErr)
              $stderr << "PBS installation of RubyGems could not get required: #{$!}.\nException stack:\n#{$!.backtrace.join("\n")}\n"
            end
          end
          rSuccess = false
        end
      end

      return rSuccess
    end

    # Install a Gem
    # It calls the internal API of RubyGems: do not invoke gem binary, as it has to work also in an embedded binary (RubyGems statically compiled in Ruby) for packaging.
    #
    # Parameters:
    # * *iInstallDir* (_String_): The directory to install the Gem to.
    # * *iInstallCmd* (_String_): The gem install parameters
    # * *iProgressDialog* (<em>Wx::ProgressDialog</em>): The progress dialog to update eventually (nil if none)
    # * *iAcceptDialogs* (_Boolean_): Do we accept displaying dialogs ? This is used to indicate that this method is called without wxruby environment set up. [optional = true]
    # Return:
    # * _Boolean_: Success ?
    def installGem(iInstallDir, iInstallCmd, iProgressDialog, iAcceptDialogs = true)
      rSuccess = true

      # Create the RubyGems command
      lRubyGemsInstallCmd = Gem::InstallCommand.new
      lRubyGemsInstallCmd.handle_options(iInstallCmd.split + [ '-i', iInstallDir, '--no-rdoc', '--no-ri', '--no-test' ] )
      logInfo "Installing Gem \"#{iInstallCmd}\" in directory #{iInstallDir} ..."
      begin
        lRubyGemsInstallCmd.execute
        logInfo 'Gem successfully installed.'
      rescue Gem::SystemExitException
        # For RubyGems, this is normal behaviour: success results in an exception thrown with exit_code 0.
        if ($!.exit_code != 0)
          if (iAcceptDialogs)
            logBug "RubyGems returned error code #{$!.exit_code} while installing #{iInstallCmd}."
          else
            if ($PBS_ScreenOutputErr)
              $stderr << "RubyGems returned error code #{$!.exit_code} while installing #{iInstallCmd}.\n"
            end
          end
          rSuccess = false
        end
      rescue Exception
        if (iAcceptDialogs)
          logExc $!, "RubyGems returned an exception while installing #{iInstallCmd}"
        else
          if ($PBS_ScreenOutputErr)
            $stderr << "RubyGems returned an exception while installing #{iInstallCmd}: #{$!}\nException stack:\n#{$!.backtrace.join("\n")}\n"
          end
        end
        rSuccess = false
      end

      return rSuccess
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

    # Get a stack trace in a simple format:
    # Remove $PBS_RootDir paths from it.
    #
    # Parameters:
    # * *iCaller* (<em>list<String></em>): The caller
    # * *iReferenceCaller* (<em>list<String></em>): The reference caller: we will not display lines from iCaller that also belong to iReferenceCaller [optional = nil]
    # Return:
    # * <em>list<String></em>): The simple stack
    def getSimpleCaller(iCaller, iReferenceCaller = nil)
      rSimpleCaller = []

      lCaller = nil
      # If there is a reference caller, remove the lines from lCaller that are also in iReferenceCaller
      if (iReferenceCaller == nil)
        lCaller = iCaller
      else
        lIdxCaller = iCaller.size - 1
        lIdxRef = iReferenceCaller.size - 1
        while ((lIdxCaller >= 0) and
               (lIdxRef >= 0) and
               (iCaller[lIdxCaller] == iReferenceCaller[lIdxRef]))
          lIdxCaller -= 1
          lIdxRef -= 1
        end
        # Here we have either one of the indexes that is -1, or the indexes point to different lines between the caller and its reference.
        lCaller = iCaller[0..lIdxCaller+1]
      end
      lCaller.each do |iCallerLine|
        lMatch = iCallerLine.match(/^(.*):([[:digit:]]*):in (.*)$/)
        if (lMatch == nil)
          # Did not get which format. Just add it blindly.
          rSimpleCaller << iCallerLine
        else
          rSimpleCaller << "#{File.expand_path(lMatch[1]).gsub($PBS_RootDir, '')}:#{lMatch[2]}:in #{lMatch[3]}"
        end
      end

      return rSimpleCaller
    end

    # Log an exception
    # This is called when there is a bug due to an exception in the program. It has been set in many places to detect bugs.
    #
    # Parameters:
    # * *iException* (_Exception_): Exception
    # * *iMsg* (_String_): Message to log
    def logExc(iException, iMsg)
      logBug("#{iMsg}
Exception: #{iException}
Exception stack:
#{getSimpleCaller(iException.backtrace, caller).join("\n")}
...")
    end

    # Log a bug
    # This is called when there is a bug in the program. It has been set in many places to detect bugs.
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logBug(iMsg)
      lCompleteMsg = "Bug: #{iMsg}
Stack:
#{getSimpleCaller(caller[0..-2]).join("\n")}"
      # Log into stderr
      if ($PBS_ScreenOutputErr)
        $stderr << "!!! BUG !!! #{lCompleteMsg}\n"
      end
      if ($PBS_LogFile != nil)
        Tools::logFile(lCompleteMsg)
      end
      # Display dialog
      # We require the file here, as we hope it will not be required often
      require 'Windows/BugReportDialog'
      showModal(BugReportDialog, nil, lCompleteMsg) do |iModalResult, iDialog|
        # Nothing to do
      end
    end

    # Log a bug when the application is not yet initialized
    # This is called when there is a bug in the program. It has been set in many places to detect bugs.
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def self.logBugBase(iMsg)
      lCallers = []
      caller[0..-2].each do |iCallerLine|
        lCallers << iCallerLine.gsub($PBS_RootDir, '')
      end
      lCompleteMsg = "Bug: #{iMsg}\nStack:\n#{lCallers.join("\n")}\nNormally you should never encounter this message. Please fill a bug report to PBS with this information to make sure it will be corrected in future releases. Thanks."
      # Log into stderr
      if ($PBS_ScreenOutputErr)
        $stderr << "!!! BUG !!! #{lCompleteMsg}\n"
      end
      if ($PBS_LogFile != nil)
        Tools::logFile(lCompleteMsg)
      end
      # Display dialog using OS dependent ways: don't rely on wxRuby.
      $PBS_Platform.sendMsg(lCompleteMsg)
    end

    # Log an error.
    # Those errors can be normal, as they mainly depend on external factors (lost connection, invalid user file...)
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logErr(iMsg)
      # Log into stderr
      if ($PBS_ScreenOutputErr)
        $stderr << "!!! ERR !!! #{iMsg}\n"
      end
      if ($PBS_LogFile != nil)
        Tools::logFile(iMsg)
      end
      # Display dialog
      showModal(Wx::MessageDialog, nil,
        iMsg,
        :caption => 'Error',
        :style => Wx::OK|Wx::ICON_ERROR
      ) do |iModalResult, iDialog|
        # Nothing to do
      end
    end

    # Log a normal message to the user
    # This is used to display a simple message to the user
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logMsg(iMsg)
      # Log into stderr
      if ($PBS_ScreenOutput)
        $stdout << "#{iMsg}\n"
      end
      if ($PBS_LogFile != nil)
        Tools::logFile(iMsg)
      end
      # Display dialog
      showModal(Wx::MessageDialog, nil,
        iMsg,
        :caption => 'Notification',
        :style => Wx::OK|Wx::ICON_INFORMATION
      ) do |iModalResult, iDialog|
        # Nothing to do
      end
    end

    # Log an info.
    # This is just common journal.
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logInfo(iMsg)
      # Log into stdout
      if ($PBS_ScreenOutput)
        $stdout << "#{iMsg}\n"
      end
      if ($PBS_LogFile != nil)
        Tools::logFile(iMsg)
      end
    end

    # Log a debugging info.
    # This is used when debug is activated
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logDebug(iMsg)
      # Log into stdout
      if (($PBS_DevDebug) and
          ($PBS_ScreenOutput))
        $stdout << "#{iMsg}\n"
      end
      if ($PBS_LogFile != nil)
        Tools::logFile(iMsg)
      end
    end

    # Log a message in the log file
    #
    # Parameters:
    # * *iMsg* (_String_): The message to log
    def self.logFile(iMsg)
      File.open($PBS_LogFile, 'a+') do |oFile|
        oFile << "#{Time.now.gmtime.strftime('%Y/%m/%d %H:%M:%S')} - #{iMsg}\n"
      end
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

    # Display a dialog in modal mode, ensuring it is destroyed afterwards.
    #
    # Parameters:
    # * *iDialogClass* (_class_): Class of the dialog to display
    # * *iParentWindow* (<em>Wx::Window</em>): Parent window
    # * *iParameters* (...): List of parameters to give the constructor
    # * *CodeBlock*: The code called once the dialog has been displayed and modally closed
    # ** *iModalResult* (_Integer_): Modal result
    # ** *iDialog* (<em>Wx::Dialog</em>): The dialog
    def showModal(iDialogClass, iParentWindow, *iParameters)
      lDialog = iDialogClass.new(iParentWindow, *iParameters)
      lDialog.centre(Wx::CENTRE_ON_SCREEN|Wx::BOTH)
      lModalResult = lDialog.show_modal
      yield(lModalResult, lDialog)
      # If we destroy the window, we get SegFaults during execution when mouse hovers some toolbar icons and moves (except if we disable GC: in this case it works perfectly fine, but consumes tons of memory).
      # If we don't destroy, we get ObjectPreviouslyDeleted exceptions on exit.
      # So the least harmful is to destroy it without GC.
      # TODO: Find a good solution
      lDialog.destroy
    end

    # Return a valid file name based on a String
    #
    # Parameters:
    # * *iName* (_String_): The initial string
    # Return:
    # * _String_: The valid file name
    def getValidFileName(iName)
      return iName.gsub(/[\\\/:\*?"<>|]/,'_')
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
      # See if we can read the icon
      rIconBitmap = nil

      lMatchData = iIconData.match(/data:image\/(.*);base64,(.*)/)
      if (lMatchData != nil)
        lImageExt = lMatchData[1]
        if (lImageExt == 'x-icon')
          lImageExt = 'ico'
        end
        # Here we unpack the string in a base64 encoding.
        lIconInternalData = lMatchData[2].unpack('m')[0]
        if (!lMatchData[2].empty?)
          # Require a temporary file
          lFileName = "#{Dir.tmpdir}/#{object_id}.#{lImageExt}"
          File.open(lFileName, 'wb') do |oFile|
            oFile.write(lIconInternalData)
          end
          # Read it
          begin
            rIconBitmap = Wx::Bitmap.new(lFileName)
          rescue Exception
            logBug "Unable to read bitmap data of format #{lImageExt}: #{$!}. Ignoring this bitmap."
            rIconBitmap = nil
          end
          # Delete the temporary file
          File.unlink(lFileName)
        end
      end

      return rIconBitmap
    end

    # Access a file: it calls a code block with a local file name corresponding to the file we want to read.
    # For local files, this is obvious.
    # For URLs, download first file from a URL into a temporary file, and execute a code on it.
    # Works with URL from http, https, ftp, ftps, file, and local files otherwise.
    #
    # Parameters:
    # * *iFileURL* (_String_): The file URL to download
    # * *CodeBlock*: The code invoked if the temporary file exists:
    # ** *iFileName* (_String_): Name of the local temporary file
    # Return:
    # * _Boolean_: Success ?
    def accessFile(iFileURL)
      rSuccess = false

      lFileName = nil
      lTemporary = false
      lHTTPMatch = iFileURL.match(/^(http|https):\/\/([^\/]*)\/(.*)$/)
      if (lHTTPMatch != nil)
        lHTTPServer, lHTTPPath = lHTTPMatch[2..3]
        # Keep the extension in the temporary file
        lFileName = "#{Dir.tmpdir}/PBS_#{self.object_id}#{File.extname(iFileURL)}"
        # Download iFileURL to lFileName
        begin
          Net::HTTP.start(lHTTPServer) do |iHTTPConnection|
            lResponse = iHTTPConnection.get("/#{lHTTPPath}")
            File.open(lFileName, 'wb') do |oFile|
              oFile.write(lResponse.body)
            end
          end
          lTemporary = true
        rescue Exception
          logErr "Exception while downloading file #{iFileURL}: #{$!}"
          lFileName = nil
        end
      else
        lFTPMatch = iFileURL.match(/^(ftp|ftps):\/\/([^\/]*)\/(.*)$/)
        if (lFTPMatch != nil)
          lFTPServer, lFTPPath = lFTPMatch[2..3]
          lFileName = "#{Dir.tmpdir}/PBS_#{self.object_id}#{File.extname(iFileURL)}"
          # Download iFileURL to lFileName
          begin
            lFTPConnection = Net::FTP.new(lFTPServer)
            lFTPConnection.login
            lFTPConnection.chdir(File.dirname(lFTPPath))
            lFTPConnection.getbinaryfile(File.basename(lFTPPath), lFileName)
            lFTPConnection.close
            lTemporary = true
          rescue Exception
            logerr "Exception while retrieving icon from #{iFileName}: #{$!}. Ignoring this icon."
            lFileName = nil
          end
        else
          lLocalFileMatch = iFileURL.match(/^file:\/\/\/(.*)$/)
          if (lLocalFileMatch != nil)
            lFileName = lLocalFileMatch[1]
          else
            # Assume it is a local file
            lFileName = iFileURL
          end
        end
      end
      if (lFileName != nil)
        yield(lFileName)
        rSuccess = true
        # Delete the temporary file
        if (lTemporary)
          File.unlink(lFileName)
        end
      end

      return rSuccess
    end

    # Extract a Zip archive in a given system dependent lib sub-directory
    #
    # Parameters:
    # * *iZipFileName* (_String_): The zip file name to extract content from
    # * *iDirName* (_String_): The name of the directory to store the zip to
    # Return:
    # * _Boolean_: Success ?
    def extractZipFile(iZipFileName, iDirName)
      rSuccess = true

      # Extract content of iFileName to #{$PBS_ExtDllsDir}/#{iLibName}
      begin
        # We don't put this require in the global scope as it needs first a DLL to be loaded by plugins
        require 'zip/zipfilesystem'
        Zip::ZipInputStream::open(iZipFileName) do |iZipFile|
          while (lEntry = iZipFile.get_next_entry)
            lDestFileName = "#{iDirName}/#{lEntry.name}"
            if (lEntry.directory?)
              FileUtils::mkdir_p(lDestFileName)
            else
              FileUtils::mkdir_p(File.dirname(lDestFileName))
              lEntry.extract(lDestFileName)
            end
          end
        end
      rescue Exception
        logExc $!, "Exception while unzipping #{iZipFileName} into #{iDirName}"
        rSuccess = false
      end

      return rSuccess
    end

    # Get a bitmap/icon from a file.
    # If no type has been provided, it detects the type of icon based on the file extension.
    #
    # Parameters:
    # * *iFileName* (_String_): The file name
    # * *iIconIndex* (_Integer_): Specify the icon index (used by Windows for EXE/DLL/ICO...) [optional = nil]
    # * *iBitmapType* (_Integer_): Bitmap/Icon type. Can be nil for autodetection. [optional = nil]
    # Return:
    # * <em>Wx::Bitmap</em>: The bitmap, or nil in case of failure
    def getBitmapFromFile(iFileName, iIconIndex = nil, iBitmapType = nil)
      rBitmap = nil

      lBitmapType = iBitmapType
      if (iBitmapType == nil)
        # Autodetect
        case File.extname(iFileName).upcase
        when '.PNG'
          lBitmapType = Wx::BITMAP_TYPE_PNG
        when '.GIF'
          lBitmapType = Wx::BITMAP_TYPE_GIF
        when '.JPG', '.JPEG'
          lBitmapType = Wx::BITMAP_TYPE_JPEG
        when '.PCX'
          lBitmapType = Wx::BITMAP_TYPE_PCX
        when '.PNM'
          lBitmapType = Wx::BITMAP_TYPE_PNM
        when '.XBM'
          lBitmapType = Wx::BITMAP_TYPE_XBM
        when '.XPM'
          lBitmapType = Wx::BITMAP_TYPE_XPM
        when '.BMP'
          lBitmapType = Wx::BITMAP_TYPE_BMP
        when '.ICO', '.CUR', '.ANI', '.EXE', '.DLL'
          lBitmapType = Wx::BITMAP_TYPE_ICO
        else
          logBug "Unable to determine the bitmap type corresponding to extension #{File.extname(iFileName).upcase}. Assuming ICO."
          lBitmapType = Wx::BITMAP_TYPE_ICO
        end
      end
      # iFileName can be a URL or whatever
      accessFile(iFileName) do |iRealFileName|
        # Special case for the ICO type
        if (lBitmapType == Wx::BITMAP_TYPE_ICO)
          lIconID = iRealFileName
          if ((iIconIndex != nil) and
              (iIconIndex != 0))
            # TODO: Currently this implementation does not work. Uncomment when ok.
            #lIconID += ";#{iIconIndex}"
          end
          rBitmap = Wx::Bitmap.new
          begin
            rBitmap.copy_from_icon(Wx::Icon.new(lIconID, Wx::BITMAP_TYPE_ICO))
          rescue Exception
            logBug "Error while loading icon from #{lIconID}: #{$!}. Ignoring it."
            rBitmap = nil
          end
        else
          rBitmap = Wx::Bitmap.new(iRealFileName, lBitmapType)
        end
      end

      return rBitmap
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
                if ((iExistingShortcut.Type.pluginName == iSerializedShortcut.TypePluginName) and
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
      lBitmapToMerge = iBitmap
      if ((iBitmap.width != ioDC.size.width) or
          (iBitmap.height != ioDC.size.height))
        # First we resize the bitmap
        lBitmapToMerge = Wx::Bitmap.from_image(iBitmap.convert_to_image.scale(ioDC.size.width, ioDC.size.height))
      end
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

    # Create an image list, considering the minimal size of every image given as input.
    #
    # Parameters:
    # * *iFileNames* (<em>list<String></em>): File names list, relative to PBS directory
    # Return:
    # * <em>Wx::ImageList</em>: The image list
    def createImageList(iFileNames)
      lBitmapList = []
      lMinWidth = nil
      lMinHeight = nil
      # Read every file given as input, and get minimal width/height
      iFileNames.each do |iFileName|
        lBitmap = Wx::Bitmap.new("#{$PBS_GraphicsDir}/#{iFileName}")
        if ((lMinWidth == nil) or
            (lBitmap.width < lMinWidth))
          lMinWidth = lBitmap.width
        end
        if ((lMinHeight == nil) or
            (lBitmap.height < lMinHeight))
          lMinHeight = lBitmap.height
        end
        lBitmapList << lBitmap
      end
      if (lMinWidth == nil)
        # No image, empty list will be returned
        lMinWidth = 0
        lMinHeight = 0
      end
      # Create the image list and populate it with the previously read bitmaps
      rImageList = Wx::ImageList.new(lMinWidth, lMinHeight)
      lBitmapList.each do |iBitmap|
        rImageList << iBitmap
      end
      return rImageList
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
      case lKey
      when Wx::K_BACK
        rResult << 'Backspace'
      when Wx::K_TAB
        rResult << 'Tab'
      when Wx::K_RETURN
        rResult << 'Enter'
      when Wx::K_ESCAPE
        rResult << 'Escape'
      when Wx::K_SPACE
        rResult << 'Space'
      when Wx::K_DELETE
        rResult << 'Del'
      when Wx::K_START
        rResult << 'Start'
      when Wx::K_LBUTTON
        rResult << 'Mouse Left'
      when Wx::K_RBUTTON
        rResult << 'Mouse Right'
      when Wx::K_CANCEL
        rResult << 'Cancel'
      when Wx::K_MBUTTON
        rResult << 'Mouse Middle'
      when Wx::K_CLEAR
        rResult << 'Clear'
      when Wx::K_SHIFT
        rResult << 'Shift'
      when Wx::K_ALT
        rResult << 'Alt'
      when Wx::K_CONTROL
        rResult << 'Control'
      when Wx::K_MENU
        rResult << 'Menu'
      when Wx::K_PAUSE
        rResult << 'Pause'
      when Wx::K_CAPITAL
        rResult << 'Capital'
      when Wx::K_END
        rResult << 'End'
      when Wx::K_HOME
        rResult << 'Home'
      when Wx::K_LEFT
        rResult << 'Left'
      when Wx::K_UP
        rResult << 'Up'
      when Wx::K_RIGHT
        rResult << 'Right'
      when Wx::K_DOWN
        rResult << 'Down'
      when Wx::K_SELECT
        rResult << 'Select'
      when Wx::K_PRINT
        rResult << 'Print'
      when Wx::K_EXECUTE
        rResult << 'Execute'
      when Wx::K_SNAPSHOT
        rResult << 'Snapshot'
      when Wx::K_INSERT
        rResult << 'Ins'
      when Wx::K_HELP
        rResult << 'Help'
      when Wx::K_NUMPAD0
        rResult << 'Num 0'
      when Wx::K_NUMPAD1
        rResult << 'Num 1'
      when Wx::K_NUMPAD2
        rResult << 'Num 2'
      when Wx::K_NUMPAD3
        rResult << 'Num 3'
      when Wx::K_NUMPAD4
        rResult << 'Num 4'
      when Wx::K_NUMPAD5
        rResult << 'Num 5'
      when Wx::K_NUMPAD6
        rResult << 'Num 6'
      when Wx::K_NUMPAD7
        rResult << 'Num 7'
      when Wx::K_NUMPAD8
        rResult << 'Num 8'
      when Wx::K_NUMPAD9
        rResult << 'Num 9'
      when Wx::K_MULTIPLY
        rResult << '*'
      when Wx::K_ADD
        rResult << '+'
      when Wx::K_SEPARATOR
        rResult << 'Separator'
      when Wx::K_SUBTRACT
        rResult << '-'
      when Wx::K_DECIMAL
        rResult << '.'
      when Wx::K_DIVIDE
        rResult << '/'
      when Wx::K_F1
        rResult << 'F1'
      when Wx::K_F2
        rResult << 'F2'
      when Wx::K_F3
        rResult << 'F3'
      when Wx::K_F4
        rResult << 'F4'
      when Wx::K_F5
        rResult << 'F5'
      when Wx::K_F6
        rResult << 'F6'
      when Wx::K_F7
        rResult << 'F7'
      when Wx::K_F8
        rResult << 'F8'
      when Wx::K_F9
        rResult << 'F9'
      when Wx::K_F10
        rResult << 'F10'
      when Wx::K_F11
        rResult << 'F11'
      when Wx::K_F12
        rResult << 'F12'
      when Wx::K_F13
        rResult << 'F13'
      when Wx::K_F14
        rResult << 'F14'
      when Wx::K_F15
        rResult << 'F15'
      when Wx::K_F16
        rResult << 'F16'
      when Wx::K_F17
        rResult << 'F17'
      when Wx::K_F18
        rResult << 'F18'
      when Wx::K_F19
        rResult << 'F19'
      when Wx::K_F20
        rResult << 'F20'
      when Wx::K_F21
        rResult << 'F21'
      when Wx::K_F22
        rResult << 'F22'
      when Wx::K_F23
        rResult << 'F23'
      when Wx::K_F24
        rResult << 'F24'
      when Wx::K_NUMLOCK
        rResult << 'Numlock'
      when Wx::K_SCROLL
        rResult << 'Scroll'
      when Wx::K_PAGEUP
        rResult << 'PageUp'
      when Wx::K_PAGEDOWN
        rResult << 'PageDown'
      when Wx::K_NUMPAD_SPACE
        rResult << 'Num Space'
      when Wx::K_NUMPAD_TAB
        rResult << 'Num Tab'
      when Wx::K_NUMPAD_ENTER
        rResult << 'Num Enter'
      when Wx::K_NUMPAD_F1
        rResult << 'Num F1'
      when Wx::K_NUMPAD_F2
        rResult << 'Num F2'
      when Wx::K_NUMPAD_F3
        rResult << 'Num F3'
      when Wx::K_NUMPAD_F4
        rResult << 'Num F4'
      when Wx::K_NUMPAD_HOME
        rResult << 'Num Home'
      when Wx::K_NUMPAD_LEFT
        rResult << 'Num Left'
      when Wx::K_NUMPAD_UP
        rResult << 'Num Up'
      when Wx::K_NUMPAD_RIGHT
        rResult << 'Num Right'
      when Wx::K_NUMPAD_DOWN
        rResult << 'Num Down'
      when Wx::K_NUMPAD_PAGEUP
        rResult << 'Num PageUp'
      when Wx::K_NUMPAD_PAGEDOWN
        rResult << 'Num PageDown'
      when Wx::K_NUMPAD_END
        rResult << 'Num End'
      when Wx::K_NUMPAD_BEGIN
        rResult << 'Num Begin'
      when Wx::K_NUMPAD_INSERT
        rResult << 'Num Ins'
      when Wx::K_NUMPAD_DELETE
        rResult << 'Num Del'
      when Wx::K_NUMPAD_EQUAL
        rResult << 'Num ='
      when Wx::K_NUMPAD_MULTIPLY
        rResult << 'Num *'
      when Wx::K_NUMPAD_ADD
        rResult << 'Num +'
      when Wx::K_NUMPAD_SEPARATOR
        rResult << 'Num Separator'
      when Wx::K_NUMPAD_SUBTRACT
        rResult << 'Num -'
      when Wx::K_NUMPAD_DECIMAL
        rResult << 'Num .'
      when Wx::K_NUMPAD_DIVIDE
        rResult << 'Num /'
      when Wx::K_WINDOWS_LEFT
        rResult << 'Win Left'
      when Wx::K_WINDOWS_RIGHT
        rResult << 'Win Right'
      when Wx::K_WINDOWS_MENU
        rResult << 'Win Menu'
      when Wx::K_COMMAND
        rResult << 'Command'
      when Wx::K_SPECIAL1
        rResult << 'Special 1'
      when Wx::K_SPECIAL2
        rResult << 'Special 2'
      when Wx::K_SPECIAL3
        rResult << 'Special 3'
      when Wx::K_SPECIAL4
        rResult << 'Special 4'
      when Wx::K_SPECIAL5
        rResult << 'Special 5'
      when Wx::K_SPECIAL6
        rResult << 'Special 6'
      when Wx::K_SPECIAL7
        rResult << 'Special 7'
      when Wx::K_SPECIAL8
        rResult << 'Special 8'
      when Wx::K_SPECIAL9
        rResult << 'Special 9'
      when Wx::K_SPECIAL10
        rResult << 'Special 10'
      when Wx::K_SPECIAL11
        rResult << 'Special 11'
      when Wx::K_SPECIAL12
        rResult << 'Special 12'
      when Wx::K_SPECIAL13
        rResult << 'Special 13'
      when Wx::K_SPECIAL14
        rResult << 'Special 14'
      when Wx::K_SPECIAL15
        rResult << 'Special 15'
      when Wx::K_SPECIAL16
        rResult << 'Special 16'
      when Wx::K_SPECIAL17
        rResult << 'Special 17'
      when Wx::K_SPECIAL18
        rResult << 'Special 18'
      when Wx::K_SPECIAL19
        rResult << 'Special 19'
      when Wx::K_SPECIAL20
        rResult << 'Special 20'
      else
        rResult << lKey.chr.upcase
      end

      return rResult
    end

  end

end
