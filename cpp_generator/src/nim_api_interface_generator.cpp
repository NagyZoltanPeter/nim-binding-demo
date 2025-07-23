// === protoc-gen-dispatcher.cpp ===
// A basic protoc plugin generating C++ event dispatcher code from `on*Event` messages.

#include <google/protobuf/compiler/code_generator.h>
#include <google/protobuf/descriptor.h>
#include <google/protobuf/io/printer.h>
#include <google/protobuf/io/zero_copy_stream.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>
#include <google/protobuf/compiler/plugin.h>
#include <fstream>
#include <iostream>

using namespace google::protobuf;
using namespace google::protobuf::compiler;
using namespace google::protobuf::io;

class DispatcherCodeGenerator : public CodeGenerator {
public:
    // Override to support proto3 optional fields
    uint64_t GetSupportedFeatures() const override {
        return FEATURE_PROTO3_OPTIONAL;
    }
    
    bool Generate(const FileDescriptor* file,
                  const std::string& parameter,
                  GeneratorContext* context,
                  std::string* error) const override {

        std::string base_filename = file->name();
        size_t last_dot = base_filename.find_last_of(".");
        if (last_dot != std::string::npos) {
            base_filename = base_filename.substr(0, last_dot);
        }

        // Generate header
        std::unique_ptr<ZeroCopyOutputStream> header_output(
            context->Open(base_filename + ".dispatcher.h"));
        Printer header_printer(header_output.get(), '$');

        header_printer.Print("#pragma once\n");
        header_printer.Print("#include <unordered_map>\n#include <string>\n#include <functional>\n#include <google/protobuf/message.h>\n\n");

        for (int i = 0; i < file->message_type_count(); ++i) {
            const Descriptor* message = file->message_type(i);
            std::string msg_name = message->name();
            if (msg_name.rfind("on", 0) == 0 && msg_name.size() > 7 && msg_name.substr(msg_name.size() - 5) == "Event") {
                header_printer.Print("#include \"$name$.pb.h\"\n", "name", base_filename);
                break;
            }
        }

        header_printer.Print("\nclass EventDispatcher {\npublic:\n");
        header_printer.Print("  using Handler = std::function<void(const google::protobuf::Message&)>;\n");
        header_printer.Print("  static EventDispatcher& instance();\n\n");
        header_printer.Print("  void dispatch(const std::string& name, const void* data, size_t len);\n\n");
        header_printer.Print("  template<typename T>\n");
        header_printer.Print("  void registerHandler(const std::string& name, std::function<void(T)> handler) {\n");
        header_printer.Print("    handlers_[name] = [handler](const google::protobuf::Message& msg) {\n");
        header_printer.Print("      handler(static_cast<const T&>(msg));\n    };\n  }\n\n");
        header_printer.Print("private:\n  std::unordered_map<std::string, Handler> handlers_;\n};\n");

        // Generate cpp
        std::unique_ptr<ZeroCopyOutputStream> cpp_output(
            context->Open(base_filename + ".dispatcher.cpp"));
        Printer cpp_printer(cpp_output.get(), '$');

        cpp_printer.Print("#include \"$base$.dispatcher.h\"\n", "base", base_filename);
        cpp_printer.Print("#include \"$base$.pb.h\"\n\n", "base", base_filename);
        cpp_printer.Print("EventDispatcher& EventDispatcher::instance() {\n");
        cpp_printer.Print("  static EventDispatcher inst;\n  return inst;\n}\n\n");

        cpp_printer.Print("void EventDispatcher::dispatch(const std::string& name, const void* data, size_t len) {\n");

        for (int i = 0; i < file->message_type_count(); ++i) {
            const Descriptor* message = file->message_type(i);
            std::string msg_name = message->name();
            if (msg_name.rfind("on", 0) == 0 && msg_name.size() > 7 && msg_name.substr(msg_name.size() - 5) == "Event") {
                std::string event_name = msg_name.substr(2, msg_name.size() - 7); // strip on/Event
                cpp_printer.Print("  if (name == \"on$name$\") {\n", "name", event_name);
                cpp_printer.Print("    $msg$ msg;\n", "msg", msg_name);
                cpp_printer.Print("    if (msg.ParseFromArray(data, len)) {\n      handlers_[name](msg);\n    }\n  } else ", "msg", msg_name);
            }
        }
        cpp_printer.Print("{ /* unknown */ }\n}\n");

        return true;
    }
};

int main(int argc, char* argv[]) {
    DispatcherCodeGenerator generator;
    return PluginMain(argc, argv, &generator);
}
