#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Class that stores missing dependencies for our plugins
  class MissingDependencies

    include Tools

    # Map of missing gems, along with their install command
    #   map< String, String >
    attr_reader :MissingGems

    # Map of missing Libs: for each library name, the file to download it from
    #   map< String, String >
    attr_reader :MissingLibs

    # Map of missing plugins (that is, plugins having missing dependencies)
    #   map< [ String, String ], [ list< String >, list< String >, list< Object >, map< Symbol, Object >, map< String, map< Symbol, Object > > ]
    attr_reader :MissingPlugins

    # Constructor
    def initialize
      # Map of missing Gems: for each require name, the gem install command
      # map< String, String >
      @MissingGems = {}
      # Map of missing Libs: for each library name, the file to download it from
      # map< String, String >
      @MissingLibs = {}
      # Map of missing plugins: for each [ plugin type, plugin name ], the list of missing gem requires, the list of missing libs, the parameters to give the constructor, the corresponding plugin info to update and the plugins map where the plugin info will be inserted
      # map< [ String, String ], [ list< String >, list< String >, list< Object >, map< Symbol, Object >, map< String, map< Symbol, Object > > ]
      @MissingPlugins = {}
    end

    # Add a missing gem
    #
    # Parameters:
    # * *iPluginTypeID* (_String_): The plugin type
    # * *iPluginName* (_String_): The plugin name
    # * *iRequireName* (_String_): The require missing
    # * *iGemInstallCommand* (_String_): The gem install command
    # * *ioPluginInfo* (<em>map<Symbol,Object></em>): The corresponding plugin info
    # * *ioPluginsMap* (<em>map<String,map<Symbol,Object>></em>): The plugins map where the plugin info will be inserted
    # * *iParams* (<em>list<Object></em>): Additional parameters to give to the plugin constructor
    def addMissingGem(iPluginTypeID, iPluginName, iRequireName, iGemInstallCommand, ioPluginInfo, ioPluginsMap, iParams)
      # Register the missing Gem
      if (@MissingGems[iRequireName] != nil)
        # Check there is no conflict
        if (iGemInstallCommand != @MissingGems[iRequireName])
          logBug "Conflict of gems to install between 2 plugins. They both want to install #{iRequireName}. One wants '#{@MissingGems[iRequireName]}', the other '#{iGemInstallCommand}'.\nPlease check .dep.rb files that declare dependencies.\nWill use '#{iGemInstallCommand}'."
        end
      end
      @MissingGems[iRequireName] = iGemInstallCommand
      # Add the missing gem
      registerPlugin(iPluginTypeID, iPluginName, ioPluginInfo, ioPluginsMap, iParams)[0] << iRequireName
    end

    # Add a missing lib
    #
    # Parameters:
    # * *iPluginTypeID* (_String_): The plugin type
    # * *iPluginName* (_String_): The plugin name
    # * *iLibName* (_String_): The library missing
    # * *iLibURL* (_String_): The library URL
    # * *ioPluginInfo* (<em>map<Symbol,Object></em>): The corresponding plugin info
    # * *ioPluginsMap* (<em>map<String,map<Symbol,Object>></em>): The plugins map where the plugin info will be inserted
    # * *iParams* (<em>list<Object></em>): Additional parameters to give to the plugin constructor
    def addMissingLib(iPluginTypeID, iPluginName, iLibName, iLibURL, ioPluginInfo, ioPluginsMap, iParams)
      # Register the missing Lib
      if (@MissingLibs[iLibName] != nil)
        # Check there is no conflict
        if (iLibURL != @MissingLibs[iLibName])
          logBug "Conflict of libraries to install between 2 plugins. They both want to install #{iLibName}. One wants '#{@MissingLibs[iLibName]}', the other '#{iLibURL}'.\nPlease check .desc.rb files that declare dependencies.\nWill use '#{iLibURL}'."
        end
      end
      @MissingLibs[iLibName] = iLibURL
      # Add the missing lib
      registerPlugin(iPluginTypeID, iPluginName, ioPluginInfo, ioPluginsMap, iParams)[1] << iLibName
    end

    # Are there some missing dependencies ?
    #
    # Return:
    # * _Boolean_: Are there some missing dependencies ?
    def empty?
      return @MissingPlugins.empty?
    end

    # Get the list of plugins that depend on a particular Gem
    #
    # Parameters:
    # * *iRequireName* (_String_): The require we are looking for
    # Return:
    # * <em>list<[String,String]></em>: The list of plugin type, plugin name
    def getPluginsDependentOnGem(iRequireName)
      rList = []

      @MissingPlugins.each do |iPluginKey, iPluginDepInfo|
        iGemList, iLibList, iParams, iPluginInfo, iPluginsMap = iPluginDepInfo
        if (iGemList.include?(iRequireName))
          rList << iPluginKey
        end
      end

      return rList
    end

    # Get the list of plugins that depend on a particular Lib
    #
    # Parameters:
    # * *iLibName* (_String_): The lib we are looking for
    # Return:
    # * <em>list<[String,String]></em>: The list of plugin type, plugin name
    def getPluginsDependentOnLib(iLibName)
      rList = []

      @MissingPlugins.each do |iPluginKey, iPluginDepInfo|
        iGemList, iLibList, iParams, iPluginInfo, iPluginsMap = iPluginDepInfo
        if (iLibList.include?(iLibName))
          rList << iPluginKey
        end
      end

      return rList
    end

    private

    # Register a plugin that misses some of its dependencies
    #
    # Parameters:
    # * *iPluginTypeID* (_String_): The plugin type
    # * *iPluginName* (_String_): The plugin name
    # * *ioPluginInfo* (<em>map<Symbol,Object></em>): The corresponding plugin info
    # * *ioPluginsMap* (<em>map<String,map<Symbol,Object>></em>): The plugins map where the plugin info will be inserted
    # * *iParams* (<em>list<Object></em>): Additional parameters to give to the plugin constructor
    # Return:
    # * <em>[list<String>,list<String>]</em>: The corresponding list of missing gems and libs to complete
    def registerPlugin(iPluginTypeID, iPluginName, ioPluginInfo, ioPluginsMap, iParams)
      # Register the missing plugin
      lPluginKey = [ iPluginTypeID, iPluginName ]
      if (@MissingPlugins[lPluginKey] == nil)
        @MissingPlugins[lPluginKey] = [ [], [], iParams, ioPluginInfo, ioPluginsMap ]
      end

      return @MissingPlugins[lPluginKey]
    end

  end

end
