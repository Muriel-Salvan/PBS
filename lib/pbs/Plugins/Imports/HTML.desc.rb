#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Plugins/Deps_Nokogiri'

# * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided (additionnally to the standard ones provided by rUtilAnts):
#   * :Title (_String_): Name of the plugin
#   * :Description (_String_): Quick description
#   * :BitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
{
  :Title => 'HTML file',
  :Description => 'Import Shortcuts from an HTML file',
  :BitmapName => 'HTML.png',
  :Dependencies => [
    PBS.getNokogiriDepDesc
  ]
}
