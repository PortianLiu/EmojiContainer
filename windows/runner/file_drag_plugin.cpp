#include "file_drag_plugin.h"

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shlobj.h>
#include <shobjidl.h>
#include <windows.h>

#include <memory>
#include <string>

namespace {

HWND g_hwnd = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

// Drag local file out via Shell IDataObject (e.g. to chat apps).
bool DragFileToDesktop(const std::wstring& file_path) {
  if (g_hwnd == nullptr) {
    return false;
  }

  IShellItem* shell_item = nullptr;
  HRESULT hr = SHCreateItemFromParsingName(
      file_path.c_str(), nullptr, IID_PPV_ARGS(&shell_item));
  if (FAILED(hr) || shell_item == nullptr) {
    return false;
  }

  IDataObject* data_object = nullptr;
  hr = shell_item->BindToHandler(nullptr, BHID_SFUIObject,
                                 IID_PPV_ARGS(&data_object));
  shell_item->Release();
  if (FAILED(hr) || data_object == nullptr) {
    return false;
  }

  DWORD effect = 0;
  hr = SHDoDragDrop(g_hwnd, data_object, nullptr,
                    DROPEFFECT_COPY | DROPEFFECT_LINK, &effect);
  data_object->Release();
  return SUCCEEDED(hr);
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(size - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  return wide;
}

class FileDragPlugin {
 public:
  static void Register(flutter::BinaryMessenger* messenger, HWND hwnd) {
    g_hwnd = hwnd;

    g_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "emoji_container/file_drag",
            &flutter::StandardMethodCodec::GetInstance());

    g_channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
               result) {
          if (call.method_name() != "startDrag") {
            result->NotImplemented();
            return;
          }

          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("invalid_args", "Missing arguments");
            return;
          }

          auto path_it = args->find(flutter::EncodableValue("path"));
          if (path_it == args->end()) {
            result->Error("invalid_args", "Missing path");
            return;
          }

          const auto* path = std::get_if<std::string>(&path_it->second);
          if (path == nullptr) {
            result->Error("invalid_args", "Path must be string");
            return;
          }

          const bool ok = DragFileToDesktop(Utf8ToWide(*path));
          result->Success(flutter::EncodableValue(ok));
        });
  }
};

}  // namespace

void RegisterFileDragPlugin(flutter::FlutterViewController* controller) {
  if (controller == nullptr || controller->engine() == nullptr) {
    return;
  }
  HWND hwnd = nullptr;
  if (controller->view() != nullptr) {
    hwnd = controller->view()->GetNativeWindow();
  }
  FileDragPlugin::Register(controller->engine()->messenger(), hwnd);
}
