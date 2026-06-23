//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_gapless_loop/flutter_gapless_loop_plugin.h>
#include <record_linux/record_linux_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) flutter_gapless_loop_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterGaplessLoopPlugin");
  flutter_gapless_loop_plugin_register_with_registrar(flutter_gapless_loop_registrar);
  g_autoptr(FlPluginRegistrar) record_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "RecordLinuxPlugin");
  record_linux_plugin_register_with_registrar(record_linux_registrar);
}
