#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided (additionnally to the standard ones provided by rUtilAnts):
# ** :Title (_String_): Name of the plugin
# ** :Description (_String_): Quick description
# ** :BitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
# # Specific parameters to Shortcut Command plugins:
# ** :ShortcutTypes (<em>list<String></em>): A list of Shortcuts types that this command is applicable to. Can be nil to target all types.
{
  :Title => 'Fill default metadata',
  :Description => 'Find appropriate metadata for a Shortcut from its content',
  :BitmapName => 'FindMetadata.png',
  :ShortcutTypes => nil
}
