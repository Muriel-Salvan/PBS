#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'Windows/DependenciesGroupWindow.rb'
# Needed to copy files once downloaded
require 'fileutils'

module PBS

  # Dialog that downloads missing dependencies
  # Apart launchers, only this class has a dependency on RubyGems
  class DependenciesLoaderDialog < Wx::Dialog

    include Tools

    # Icons used
    BITMAP_GEM = Tools::loadBitmap('Gem.png')
    BITMAP_LIB = Tools::loadBitmap('Lib.png')
    BITMAP_VALID = Tools::loadBitmap('MiniValidOK.png')
    BITMAP_IGNORE = Tools::loadBitmap('MiniValidKO.png')
    BITMAP_INSTALL = Tools::loadBitmap('MiniDownload.png')

    # This class is used to handle Gem dependencies
    class GemDepHandler

      include Tools

      # Test if adding a given directory resolves the missing dependency
      #
      # Parameters:
      # * *iDepName* (_String_): The name of the dependency to resolve
      # * *iDir* (_String_): The directory to test
      # Return:
      # * _Boolean_: Is the test successfull ?
      # * _Exception_: The exception, or nil if success
      def testDirectory(iDepName, iDir)
        rSuccess = false
        rException = nil

        # Save the load paths
        lOldLoadPath = $LOAD_PATH.clone
        # Add the directory to the load paths
        $LOAD_PATH << iDir
        # Test the require
        begin
          require iDepName
          rSuccess = true
        rescue Exception
          # Test if there is a lib directory
          if (File.exists?("#{iDir}/lib"))
            $LOAD_PATH.replace(lOldLoadPath + ["#{iDir}/lib"])
            # Test again the require
            begin
              require iDepName
              rSuccess = true
            rescue Exception
              rException = $!
            end
          end
        end
        # Revert changes made for testing
        $LOAD_PATH.replace(lOldLoadPath)

        return rSuccess, rException
      end

      # Install a dependency in a given directory
      #
      # Parameters:
      # * *iDepName* (_String_): Dependency name
      # * *iInstallDir* (_String_): Directory to install to
      # * *iInstallCommand* (_String_): Command used for installation
      # * *ioProgressDialog* (<em>Wx::ProgressDialog</em>): The progress dialog (can be nil)
      # Return:
      # * _Boolean_: Success ?
      def install(iDepName, iInstallDir, iInstallCommand, ioProgressDialog)
        return installGem(iInstallDir, iInstallCommand, ioProgressDialog)
      end

      # Get the directory to add after an install in a non-standard directory
      #
      # Parameters:
      # * *iDepName* (_String_): Dependency name
      # * *iInstallDir* (_String_): Directory to install to
      # * *iInstallCommand* (_String_): Command used for installation
      # Return:
      # * <em>list<String></em>: Directories to add
      def getDirectoriesToAddAfterInstall(iDepName, iInstallDir, iInstallCommand)
        rDirs = []

        lGemName = iInstallCommand.split[0]
        lFound = false
        Dir.glob("#{iInstallDir}/gems/#{lGemName}*").each do |iDir|
          if (File.exists?("#{iDir}/lib"))
            rDirs << "#{iDir}/lib"
            lFound = true
          end
        end
        if (!lFound)
          logErr "Unable to find the installed directory #{iInstallDir}/gems/#{lGemName}*. It is possible that #{iDepName} dependency will not be installed correctly."
        end

        return rDirs
      end

    end

    # This class is used to handle libraries dependencies
    class LibDepHandler

      include Tools

      # Test if adding a given directory resolves the missing dependency
      #
      # Parameters:
      # * *iDepName* (_String_): The name of the dependency to resolve
      # * *iDir* (_String_): The directory to test
      # Return:
      # * _Boolean_: Is the test successfull ?
      # * _Exception_: The exception, or nil if success
      def testDirectory(iDepName, iDir)
        rSuccess = false
        rException = nil

        rSuccess = File.exists?("#{iDir}/#{iDepName}")
        if (!rSuccess)
          rException = Exception.new("File \"#{iDir}/#{iDepName}\" does not exist.")
        end

        return rSuccess, rException
      end

      # Install a dependency in a given directory
      #
      # Parameters:
      # * *iDepName* (_String_): Dependency name
      # * *iInstallDir* (_String_): Directory to install to
      # * *iInstallCommand* (_String_): Command used for installation
      # * *ioProgressDialog* (<em>Wx::ProgressDialog</em>): The progress dialog (can be nil)
      # Return:
      # * _Boolean_: Success ?
      def install(iDepName, iInstallDir, iInstallCommand, ioProgressDialog)
        rSuccess = false

        # Download the URL stored in iInstallCommand into iInstallDir
        # The URL can be a zip file, a targz, a direct dll file
        accessFile(iInstallCommand) do |iLocalFileName|
          case File.extname(iLocalFileName).upcase
          when '.ZIP'
            # Unzip before
            rSuccess = extractZipFile(iLocalFileName, "#{iInstallDir}/#{iDepName}")
          # TODO: Handle targz, bz...
          else
            # Just copy
            FileUtils::mkdir_p("#{iInstallDir}/#{iDepName}")
            FileUtils::cp(iLocalFileName, "#{iInstallDir}/#{iDepName}/#{File.basename(iInstallCommand)}")
          end
        end

        return rSuccess
      end

      # Get the directory to add after an install in a non-standard directory
      #
      # Parameters:
      # * *iDepName* (_String_): Dependency name
      # * *iInstallDir* (_String_): Directory to install to
      # * *iInstallCommand* (_String_): Command used for installation
      # Return:
      # * <em>list<String></em>: Directories to add
      def getDirectoriesToAddAfterInstall(iDepName, iInstallDir, iInstallCommand)
        rDirs = []

        Dir.glob("#{iInstallDir}/**/*").each do |iFileName|
          if (File.directory?(iFileName))
            rDirs << iFileName
          end
        end

        return rDirs
      end

    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iMissingDeps* (_MissingDependencies_): The missing dependencies
    def initialize(iParent, iMissingDeps)
      super(iParent,
        :title => 'Dependencies downloader',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      @MissingDeps = iMissingDeps
      # The list of additional directories, per dependency type
      # map< Symbol, list< String > >
      @AdditionalDirs = {}
      # The list of resolved dependencies, per dependency type
      # map< Symbol, list< String > >
      @ResolvedDeps = {}
      # The correspondance between require/library names and tree nodes
      # map< String, list< Integer > >
      @GemsToNodeID = {}
      @LibsToNodeID = {}

      # Create components
      @BApply = Wx::Button.new(self, Wx::ID_ANY, 'Apply')
      lStrSentence = 'Some dependencies are missing for some plugins:'
      if (!iMissingDeps.MissingGems.empty?)
        if (iMissingDeps.MissingGems.size == 1)
          lStrSentence += "\n1 Gem"
        else
          lStrSentence += "\n#{iMissingDeps.MissingGems.size} Gems"
        end
      end
      if (!iMissingDeps.MissingLibs.empty?)
        if (iMissingDeps.MissingLibs.size == 1)
          lStrSentence += "\n1 library"
        else
          lStrSentence += "\n#{iMissingDeps.MissingLibs.size} libraries"
        end
      end
      lSTMessage = Wx::StaticText.new(self, Wx::ID_ANY, "#{lStrSentence}\nPlease indicate what action to take for each one of them before continuing.",
        :style => Wx::ALIGN_CENTRE
      )
      lFont = lSTMessage.font
      lFont.weight = Wx::FONTWEIGHT_BOLD
      lSTMessage.font = lFont

      # The list of group windows for each type of dependency: [ Window, Title, Icon ], grouped per dependency type
      # map< Symbol, [ DependenciesGroupWindow, String, Wx::Bitmap ] >
      @DependencyWindows = {}

      # The tree ctrl that gives a vision of the plugins
      @TCPlugins = Wx::TreeCtrl.new(self,
        :style => Wx::TR_HAS_BUTTONS|Wx::TR_HIDE_ROOT
      )
      # Create the image list for the tree
      lTreeImageList = Wx::ImageList.new(16, 16)
      @TCPlugins.set_image_list(lTreeImageList)
      # Make this image list driven by a manager
      @TCImageListManager = ImageListManager.new(lTreeImageList, 16, 16)
      # Fill the tree
      # For each type, the corresponding tree node id
      # map< String, Integer >
      lTypeToNodeID = {}
      # For each plugin key, the corresponding tree node id
      # map< String, Integer >
      @PluginKeyToNodeID = {}
      lRootID = @TCPlugins.add_root('')
      iMissingDeps.MissingPlugins.each do |iPluginKey, iPluginDepInfo|
        iPluginTypeID, iPluginName = iPluginKey
        iGemsList, iLibsList, iParams, iPluginInfo, iPluginsMap = iPluginDepInfo
        # Check if this plugin key already has a node
        if (@PluginKeyToNodeID[iPluginKey] == nil)
          # Add a node for iPluginTypeID if it does node exist already
          if (lTypeToNodeID[iPluginTypeID] == nil)
            lTypeToNodeID[iPluginTypeID] = @TCPlugins.append_item(lRootID, iPluginTypeID)
          end
          @PluginKeyToNodeID[iPluginKey] = @TCPlugins.append_item(lTypeToNodeID[iPluginTypeID], iPluginName)
        end
        # And now, add gems and libs dependencies
        lPluginNodeID = @PluginKeyToNodeID[iPluginKey]
        iGemsList.each do |iRequireName|
          if (@GemsToNodeID[iRequireName] == nil)
            @GemsToNodeID[iRequireName] = []
          end
          @GemsToNodeID[iRequireName] << @TCPlugins.append_item(lPluginNodeID, iRequireName)
        end
        iLibsList.each do |iLibName|
          if (@LibsToNodeID[iLibName] == nil)
            @LibsToNodeID[iLibName] = []
          end
          @LibsToNodeID[iLibName] << @TCPlugins.append_item(lPluginNodeID, iLibName)
        end
      end
      @TCPlugins.expand_all

      # The notebook containing the scroll windows
      lNBDeps = Wx::Notebook.new(self)
      # Create the image list for the notebook
      lNotebookImageList = Wx::ImageList.new(16, 16)
      lNBDeps.image_list = lNotebookImageList
      # Make this image list driven by a manager
      lNBImageListManager = ImageListManager.new(lNotebookImageList, 16, 16)

      # The scroll windows, 1 per dependency type
      if (!iMissingDeps.MissingGems.empty?)
        # We want RubyGems
        lRubyGemsLoaded = ensureRubyGems
        # Build the dependencies info for the scrolled window
        lDepsList = {}
        iMissingDeps.MissingGems.each do |iRequireName, iGemInstallCommand|
          lDepsList[iRequireName] = [ iGemInstallCommand, iMissingDeps.getPluginsDependentOnGem(iRequireName) ]
        end
        if (lRubyGemsLoaded)
          @DependencyWindows[:gem] = [
            DependenciesGroupWindow.new(
              lNBDeps,
              lDepsList,
              self,
              [
                [ 'PBS directory', $PBS_ExtGemsDir ],
                [ 'Current host gems', Gem.dir ],
                [ 'Current user gems', Gem.user_dir ]
              ],
              GemDepHandler.new,
              'gem install '
            ),
            'Missing Gems',
            BITMAP_GEM
          ]
        else
          @DependencyWindows[:gem] = [
            DependenciesGroupWindow.new(
              lNBDeps,
              lDepsList,
              self,
              nil,
              GemDepHandler.new,
              'gem install '
            ),
            'Missing Gems',
            BITMAP_GEM
          ]
        end
      end

      # The window that will contain each panel corresponding to missing lib dependencies
      if (!iMissingDeps.MissingLibs.empty?)
        # Build the dependencies info for the scrolled window
        lDepsList = {}
        iMissingDeps.MissingLibs.each do |iLibName, iLibURL|
          lDepsList[iLibName] = [ iLibURL, iMissingDeps.getPluginsDependentOnLib(iLibName) ]
        end
        @DependencyWindows[:lib] = [
          DependenciesGroupWindow.new(
            lNBDeps,
            lDepsList,
            self,
            [
              [ 'PBS directory', $PBS_ExtDllsDir ]
            ],
            LibDepHandler.new,
            'Download from '
          ),
          'Missing libraries',
          BITMAP_LIB
        ]
      end

      # Add the pages to the notebook
      @DependencyWindows.each do |iDepID, iDependencyWindowInfo|
        iDependencyWindow, iTitle, iIcon = iDependencyWindowInfo
        lNBDeps.add_page(
          iDependencyWindow,
          iTitle,
          false,
          lNBImageListManager.getImageIndex(iDependencyWindow.object_id) do
            next iIcon
          end
        )
      end

      # Resize some components as they will be used for sizers
      lNBDeps.fit
      @TCPlugins.fit

      # Put everything in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lMainSizer.add_item(lSTMessage, :border => 8, :flag => Wx::ALIGN_CENTER|Wx::ALL, :proportion => 0)

      # The sizer containing the tree, the notebook and the apply button
      lContentSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lContentSizer.add_item(@TCPlugins, :flag => Wx::GROW, :proportion => @TCPlugins.size.width)

      # The sizer containing the notebook and the apply button
      lRightSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lRightSizer.add_item(lNBDeps, :flag => Wx::GROW, :proportion => 1)
      lRightSizer.add_item(@BApply, :border => 8, :flag => Wx::ALIGN_RIGHT|Wx::ALL, :proportion => 0)

      lContentSizer.add_item(lRightSizer, :flag => Wx::GROW, :proportion => lNBDeps.size.width)

      lMainSizer.add_item(lContentSizer, :flag => Wx::GROW, :proportion => 1)
      self.sizer = lMainSizer

      self.fit

      # Events
      evt_button(@BApply) do |iEvent|
        # Get the number of dependencies to ignore, and the number to install
        lNbrIgnore = 0
        lNbrInstall = 0
        @DependencyWindows.each do |iDepID, iDependencyWindowInfo|
          iDepWindow, iTitle, iIcon = iDependencyWindowInfo
          lNbrWinIgnore, lNbrWinInstall = iDepWindow.getIgnoreInstallCounters
          lNbrIgnore += lNbrWinIgnore
          lNbrInstall += lNbrWinInstall
        end
        lProgressDialog = nil
        if (lNbrInstall > 0)
          # We need to have a progress dialog, as we will need to install some dependencies
          lProgressDialog = Wx::ProgressDialog.new(
            'Dependencies installation',
            'Installing',
            lNbrInstall,
            self,
            Wx::PD_CAN_ABORT|Wx::PD_APP_MODAL
          )
        end
        # Install what is needed and get back the additional list of directories, and the list of resolved dependencies
        lNbrCount = 0
        @DependencyWindows.each do |iDepID, iDependencyWindowInfo|
          iDepWindow, iTitle, iIcon = iDependencyWindowInfo
          @AdditionalDirs[iDepID], @ResolvedDeps[iDepID] = iDepWindow.performApply(lProgressDialog, lNbrCount)
          lNbrWinIgnore, lNbrWinInstall = iDepWindow.getIgnoreInstallCounters
          lNbrCount += lNbrWinInstall
        end
        if (lProgressDialog != nil)
          lProgressDialog.destroy
        end
        self.end_modal(Wx::ID_OK)
      end

      # Update the button label
      notifyInstallDecisionChanged

    end

    # Notify that an install decision of one of the dependencies has changed
    def notifyInstallDecisionChanged
      # Update the label
      lNbrIgnore = 0
      lNbrInstall = 0
      @DependencyWindows.each do |iDepID, iDependencyWindowInfo|
        iDepWindow, iTitle, iIcon = iDependencyWindowInfo
        lNbrWinIgnore, lNbrWinInstall = iDepWindow.getIgnoreInstallCounters
        lNbrIgnore += lNbrWinIgnore
        lNbrInstall += lNbrWinInstall
      end
      @BApply.label = "Apply (Ignore #{lNbrIgnore}, Install #{lNbrInstall})"
      # Update icons of the tree
      # The gems
      @GemsToNodeID.each do |iDepName, iNodesList|
        # First get the masks for this dependency
        # Wx::Bitmap
        lMask = nil
        if (@DependencyWindows[:gem][0].depInstall?(iDepName))
          lMask = BITMAP_INSTALL
        elsif (@DependencyWindows[:gem][0].depIgnore?(iDepName))
          lMask = BITMAP_IGNORE
        else
          lMask = BITMAP_VALID
        end
        lIdxImage = @TCImageListManager.getImageIndex( [ :gem, lMask, iDepName ] ) do
          # We will apply some layers, so clone the original bitmap
          rBitmap = BITMAP_GEM.clone
          applyBitmapLayers(rBitmap, [lMask])
          next rBitmap
        end
        # Apply this to every node
        iNodesList.each do |iNodeID|
          @TCPlugins.set_item_image(iNodeID, lIdxImage)
          # This is used to compute the bitmap of the plugin after
          @TCPlugins.set_item_data(iNodeID, lMask)
        end
      end
      # The libs
      @LibsToNodeID.each do |iDepName, iNodesList|
        # First get the masks for this dependency
        # Wx::Bitmap
        lMask = nil
        if (@DependencyWindows[:lib][0].depInstall?(iDepName))
          lMask = BITMAP_INSTALL
        elsif (@DependencyWindows[:lib][0].depIgnore?(iDepName))
          lMask = BITMAP_IGNORE
        else
          lMask = BITMAP_VALID
        end
        lIdxImage = @TCImageListManager.getImageIndex( [ :lib, lMask, iDepName ] ) do
          # We will apply some layers, so clone the original bitmap
          rBitmap = BITMAP_LIB.clone
          applyBitmapLayers(rBitmap, [lMask])
          next rBitmap
        end
        # Apply this to every node
        iNodesList.each do |iNodeID|
          @TCPlugins.set_item_image(iNodeID, lIdxImage)
          # This is used to compute the bitmap of the plugin after
          @TCPlugins.set_item_data(iNodeID, lMask)
        end
      end
      # The plugins
      @PluginKeyToNodeID.each do |iPluginKey, iNodeID|
        # Check images of all its children to compute its one
        lInstall = false
        lIgnore = false
        @TCPlugins.get_children(iNodeID).each do |iChildNodeID|
          case @TCPlugins.get_item_data(iChildNodeID)
          when BITMAP_INSTALL
            lInstall = true
          when BITMAP_IGNORE
            lIgnore = true
            break
          end
        end
        lMask = nil
        if (lIgnore)
          lMask = BITMAP_IGNORE
        elsif (lInstall)
          lMask = BITMAP_INSTALL
        else
          lMask = BITMAP_VALID
        end
        lIdxImage = @TCImageListManager.getImageIndex( [ nil, lMask, iPluginKey ] ) do
          # We must retrieve the plugin icon
          # We will apply some layers, so clone the original bitmap
          rBitmap = @MissingDeps.MissingPlugins[iPluginKey][3][:bitmap].clone
          applyBitmapLayers(rBitmap, [lMask])
          next rBitmap
        end
        @TCPlugins.set_item_image(iNodeID, lIdxImage)
      end
    end

    # Return plugins that should be loadable after this dialog execution
    #
    # Return:
    # * <em>list<[String,String]></em>: List of [ plugin type, plugin name ] that should get ok
    def getLoadablePlugins
      rLoadablePlugins = []

      # Check each plugin
      @MissingDeps.MissingPlugins.each do |iPluginKey, iPluginDepInfo|
        iGemList, iLibList, iParams, iPluginInfo = iPluginDepInfo
        # Verify that each missing gem is part of the loadable ones
        lMissingGem = false
        iGemList.each do |iRequireName|
          if ((@ResolvedDeps[:gem] == nil) or
              (!@ResolvedDeps[:gem].include?(iRequireName)))
            lMissingGem = true
            break
          end
        end
        if (!lMissingGem)
          # Verify that each missing lib is part of the loadable ones
          lMissingLib = false
          iLibList.each do |iLibName|
            if ((@ResolvedDeps[:lib] == nil) or
                (!@ResolvedDeps[:lib].include?(iLibName)))
              lMissingLib = true
              break
            end
          end
          if (!lMissingLib)
            # This plugin should be loadable: all its dependencies have been resolved
            rLoadablePlugins << iPluginKey
          end
        end
      end

      return rLoadablePlugins
    end

    # Return the list of directories that should be added to initial search paths for libraries
    #
    # Return:
    # * <em>list<String></em>: List of directories to add
    def getExternalLibDirectories
      # Can be nil if no dependency of this type was to be resolved
      if (@AdditionalDirs[:gem] != nil)
        return @AdditionalDirs[:gem]
      else
        return []
      end
    end

    # Return the list of directories that should be added to initial search paths for system libraries
    #
    # Return:
    # * <em>list<String></em>: List of directories to add
    def getExternalDLLDirectories
      # Can be nil if no dependency of this type was to be resolved
      if (@AdditionalDirs[:lib] != nil)
        return @AdditionalDirs[:lib]
      else
        return []
      end
    end

  end

end
