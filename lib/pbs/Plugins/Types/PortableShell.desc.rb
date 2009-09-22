#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided (additionnally to the standard ones provided by rUtilAnts):
# ** :Title (_String_): Name of the plugin
# ** :Description (_String_): Quick description
# ** :BitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
{
  :Title => 'Portable Shell Command',
  :Description => 'Portable command line (1 per platform) to be executed by a local shell',
  :BitmapName => 'PowerRun.png',
  :PluginsDependencies => [
    # We depend on the Shell dependency
    [ 'Type', 'Shell' ]
  ]
}