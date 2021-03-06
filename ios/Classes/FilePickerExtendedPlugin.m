#import "FilePickerExtendedPlugin.h"
#if __has_include(<file_picker_extended/file_picker_extended-Swift.h>)
#import <file_picker_extended/file_picker_extended-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "file_picker_extended-Swift.h"
#endif

@implementation FilePickerExtendedPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFilePickerExtendedPlugin registerWithRegistrar:registrar];
}
@end
