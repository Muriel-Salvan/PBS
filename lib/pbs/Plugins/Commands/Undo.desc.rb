#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided (additionnally to the standard ones provided by rUtilAnts):
# ** :Title (_String_): Name of the plugin
# ** :Description (_String_): Quick description
# ** :BitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
# # Specific parameters to Command plugins:
# ** :CommandID (_Integer_): The command ID
# ** :Accelerator (<em>[Integer,Integer]</em>): The accelerator (modifier and key)
# ** :Parameters (<em>list<Symbol></em>): The list of symbols that GUIs have to provide to the execute method
{
  :Title => 'Undo',
  :Description => 'Undo last action',
  :BitmapName => 'Undo.png',
  :CommandID => Wx::ID_UNDO,
  :Accelerator => [ Wx::MOD_CMD, 'z'[0] ],
  :Parameters => []
}
