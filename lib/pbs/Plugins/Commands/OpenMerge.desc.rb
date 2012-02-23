#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided (additionnally to the standard ones provided by rUtilAnts):
#   * :Title (_String_): Name of the plugin
#   * :Description (_String_): Quick description
#   * :BitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
# # Specific parameters to Command plugins:
#   * :CommandID (_Integer_): The command ID
#   * :Accelerator (<em>[Integer,Integer]</em>): The accelerator (modifier and key)
#   * :Parameters (<em>list<Symbol></em>): The list of symbols that GUIs have to provide to the execute method
{
  :Title => 'Open and Merge',
  :Description => 'Open a PBS file and merge it with existing',
  :BitmapName => 'OpenMerge.png',
  :CommandID => PBS::ID_OPEN_MERGE,
  :Parameters => [
    :parentWindow
  ]
}
