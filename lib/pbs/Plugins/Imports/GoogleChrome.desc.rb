#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Plugins/Deps_SQLite3'

# * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided (additionnally to the standard ones provided by rUtilAnts):
# ** :Title (_String_): Name of the plugin
# ** :Description (_String_): Quick description
# ** :BitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
{
  :Title => 'Google Chrome',
  :Description => 'Import Shortcuts from current Google Chrome profile',
  :BitmapName => 'GoogleChrome.png',
  :Dependencies => PBS.getSQLite3Dependencies,
  :Enabled => ($rUtilAnts_Platform_Info.os == OS_WINDOWS)
}
