#include <google/protobuf/descriptor.h>
#include <google/protobuf/dynamic_message.h>
#include <google/protobuf/descriptor.pb.h>
#include <string>
#include <vector>
#include <tuple>
#include <type_traits>
#include <memory>
#include <iostream>

// ============================================================================
// Type mapping helpers
// ============================================================================

template<typename T>
struct ProtobufType;

template<> struct ProtobufType<std::string> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_STRING;
};

template<> struct ProtobufType<int32_t> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_INT32;
};

template<> struct ProtobufType<int64_t> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_INT64;
};

template<> struct ProtobufType<uint32_t> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_UINT32;
};

template<> struct ProtobufType<uint64_t> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_UINT64;
};

template<> struct ProtobufType<bool> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_BOOL;
};

template<> struct ProtobufType<float> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_FLOAT;
};

template<> struct ProtobufType<double> {
    static constexpr auto value = google::protobuf::FieldDescriptorProto::TYPE_DOUBLE;
};

// ============================================================================
// Field descriptor with compile-time information
// ============================================================================

template<typename T, int FieldNumber>
struct Field {
    using Type = T;
    static constexpr int number = FieldNumber;
    const char* name;
    
    constexpr Field(const char* n) : name(n) {}
};

template<typename T, int FieldNumber>
struct RepeatedField {
    using Type = T;
    using ElementType = typename T::value_type;
    static constexpr int number = FieldNumber;
    static constexpr bool is_repeated = true;
    const char* name;
    
    constexpr RepeatedField(const char* n) : name(n) {}
};

// ============================================================================
// Reflection helpers - set/get field values
// ============================================================================

namespace detail {

// Set single value field
template<typename T>
void SetField(google::protobuf::Message* msg, 
              const google::protobuf::FieldDescriptor* field,
              const T& value) {
    auto* refl = msg->GetReflection();
    
    if constexpr (std::is_same_v<T, std::string>) {
        refl->SetString(msg, field, value);
    } else if constexpr (std::is_same_v<T, int32_t>) {
        refl->SetInt32(msg, field, value);
    } else if constexpr (std::is_same_v<T, int64_t>) {
        refl->SetInt64(msg, field, value);
    } else if constexpr (std::is_same_v<T, uint32_t>) {
        refl->SetUInt32(msg, field, value);
    } else if constexpr (std::is_same_v<T, uint64_t>) {
        refl->SetUInt64(msg, field, value);
    } else if constexpr (std::is_same_v<T, bool>) {
        refl->SetBool(msg, field, value);
    } else if constexpr (std::is_same_v<T, float>) {
        refl->SetFloat(msg, field, value);
    } else if constexpr (std::is_same_v<T, double>) {
        refl->SetDouble(msg, field, value);
    }
}

// Get single value field
template<typename T>
T GetField(const google::protobuf::Message& msg,
           const google::protobuf::FieldDescriptor* field) {
    auto* refl = msg.GetReflection();
    
    if constexpr (std::is_same_v<T, std::string>) {
        return refl->GetString(msg, field);
    } else if constexpr (std::is_same_v<T, int32_t>) {
        return refl->GetInt32(msg, field);
    } else if constexpr (std::is_same_v<T, int64_t>) {
        return refl->GetInt64(msg, field);
    } else if constexpr (std::is_same_v<T, uint32_t>) {
        return refl->GetUInt32(msg, field);
    } else if constexpr (std::is_same_v<T, uint64_t>) {
        return refl->GetUInt64(msg, field);
    } else if constexpr (std::is_same_v<T, bool>) {
        return refl->GetBool(msg, field);
    } else if constexpr (std::is_same_v<T, float>) {
        return refl->GetFloat(msg, field);
    } else if constexpr (std::is_same_v<T, double>) {
        return refl->GetDouble(msg, field);
    }
}

// Add repeated field element
template<typename T>
void AddRepeated(google::protobuf::Message* msg,
                 const google::protobuf::FieldDescriptor* field,
                 const T& value) {
    auto* refl = msg->GetReflection();
    
    if constexpr (std::is_same_v<T, std::string>) {
        refl->AddString(msg, field, value);
    } else if constexpr (std::is_same_v<T, int32_t>) {
        refl->AddInt32(msg, field, value);
    } else if constexpr (std::is_same_v<T, int64_t>) {
        refl->AddInt64(msg, field, value);
    } else if constexpr (std::is_same_v<T, uint32_t>) {
        refl->AddUInt32(msg, field, value);
    } else if constexpr (std::is_same_v<T, uint64_t>) {
        refl->AddUInt64(msg, field, value);
    } else if constexpr (std::is_same_v<T, bool>) {
        refl->AddBool(msg, field, value);
    } else if constexpr (std::is_same_v<T, float>) {
        refl->AddFloat(msg, field, value);
    } else if constexpr (std::is_same_v<T, double>) {
        refl->AddDouble(msg, field, value);
    }
}

// Get repeated field element
template<typename T>
T GetRepeated(const google::protobuf::Message& msg,
              const google::protobuf::FieldDescriptor* field,
              int index) {
    auto* refl = msg.GetReflection();
    
    if constexpr (std::is_same_v<T, std::string>) {
        return refl->GetRepeatedString(msg, field, index);
    } else if constexpr (std::is_same_v<T, int32_t>) {
        return refl->GetRepeatedInt32(msg, field, index);
    } else if constexpr (std::is_same_v<T, int64_t>) {
        return refl->GetRepeatedInt64(msg, field, index);
    } else if constexpr (std::is_same_v<T, uint32_t>) {
        return refl->GetRepeatedUInt32(msg, field, index);
    } else if constexpr (std::is_same_v<T, uint64_t>) {
        return refl->GetRepeatedUInt64(msg, field, index);
    } else if constexpr (std::is_same_v<T, bool>) {
        return refl->GetRepeatedBool(msg, field, index);
    } else if constexpr (std::is_same_v<T, float>) {
        return refl->GetRepeatedFloat(msg, field, index);
    } else if constexpr (std::is_same_v<T, double>) {
        return refl->GetRepeatedDouble(msg, field, index);
    }
}

} // namespace detail

// ============================================================================
// Schema builder using variadic templates
// ============================================================================

template<typename... Fields>
class MessageSchema {
private:
    std::unique_ptr<google::protobuf::DescriptorPool> pool_;
    const google::protobuf::Descriptor* descriptor_;
    google::protobuf::DynamicMessageFactory factory_;
    std::tuple<Fields...> fields_;
    std::string message_name_;
    
    template<typename Field, std::size_t... I>
    void AddFieldToSchema(google::protobuf::DescriptorProto* message_proto,
                          const Field& field) {
        auto* field_proto = message_proto->add_field();
        field_proto->set_name(field.name);
        field_proto->set_number(Field::number);
        
        if constexpr (requires { Field::is_repeated; }) {
            field_proto->set_type(ProtobufType<typename Field::ElementType>::value);
            field_proto->set_label(google::protobuf::FieldDescriptorProto::LABEL_REPEATED);
        } else {
            field_proto->set_type(ProtobufType<typename Field::Type>::value);
            field_proto->set_label(google::protobuf::FieldDescriptorProto::LABEL_OPTIONAL);
        }
    }
    
    template<std::size_t... I>
    void BuildSchemaImpl(std::index_sequence<I...>) {
        google::protobuf::FileDescriptorProto file_proto;
        file_proto.set_name("dynamic.proto");
        file_proto.set_syntax("proto3");
        
        auto* message_proto = file_proto.add_message_type();
        message_proto->set_name(message_name_);
        
        // Add all fields
        (AddFieldToSchema(message_proto, std::get<I>(fields_)), ...);
        
        // Build descriptor
        pool_ = std::make_unique<google::protobuf::DescriptorPool>();
        const auto* file_desc = pool_->BuildFile(file_proto);
        descriptor_ = file_desc->FindMessageTypeByName(message_name_);
    }
    
public:
    MessageSchema(const char* name, Fields... fields) 
        : fields_(fields...), message_name_(name) {
        BuildSchemaImpl(std::index_sequence_for<Fields...>{});
    }
    
    // Encode: tuple of values → protobuf binary
    template<typename... Values>
    std::vector<uint8_t> encode(const Values&... values) const {
        static_assert(sizeof...(Values) == sizeof...(Fields), 
                      "Number of values must match number of fields");
        
        const auto* prototype = factory_.GetPrototype(descriptor_);
        std::unique_ptr<google::protobuf::Message> message(prototype->New());
        
        encodeImpl(message.get(), std::index_sequence_for<Fields...>{}, values...);
        
        std::string buffer;
        message->SerializeToString(&buffer);
        return std::vector<uint8_t>(buffer.begin(), buffer.end());
    }
    
    // Decode: protobuf binary → tuple of values
    template<typename... Values>
    std::tuple<Values...> decode(const std::vector<uint8_t>& buffer) const {
        const auto* prototype = factory_.GetPrototype(descriptor_);
        std::unique_ptr<google::protobuf::Message> message(prototype->New());
        
        std::string str_buffer(buffer.begin(), buffer.end());
        if (!message->ParseFromString(str_buffer)) {
            throw std::runtime_error("Failed to parse protobuf message");
        }
        
        return decodeImpl<Values...>(message.get(), std::index_sequence_for<Fields...>{});
    }
    
private:
    template<std::size_t... I, typename... Values>
    void encodeImpl(google::protobuf::Message* msg,
                    std::index_sequence<I...>,
                    const Values&... values) const {
        auto value_tuple = std::tie(values...);
        (encodeField<I>(msg, std::get<I>(fields_), std::get<I>(value_tuple)), ...);
    }
    
    template<std::size_t I, typename FieldType, typename ValueType>
    void encodeField(google::protobuf::Message* msg,
                     const FieldType& field_desc,
                     const ValueType& value) const {
        const auto* field = descriptor_->FindFieldByName(field_desc.name);
        
        if constexpr (requires { FieldType::is_repeated; }) {
            // Repeated field
            for (const auto& elem : value) {
                detail::AddRepeated(msg, field, elem);
            }
        } else {
            // Single field
            detail::SetField(msg, field, value);
        }
    }
    
    template<typename... Values, std::size_t... I>
    std::tuple<Values...> decodeImpl(const google::protobuf::Message* msg,
                                      std::index_sequence<I...>) const {
        return std::make_tuple(decodeField<Values, I>(msg, std::get<I>(fields_))...);
    }
    
    template<typename ValueType, std::size_t I, typename FieldType>
    ValueType decodeField(const google::protobuf::Message* msg,
                          const FieldType& field_desc) const {
        const auto* field = descriptor_->FindFieldByName(field_desc.name);
        const auto* refl = msg->GetReflection();
        
        if constexpr (requires { FieldType::is_repeated; }) {
            // Repeated field
            ValueType result;
            int count = refl->FieldSize(*msg, field);
            for (int i = 0; i < count; ++i) {
                result.push_back(
                    detail::GetRepeated<typename FieldType::ElementType>(*msg, field, i)
                );
            }
            return result;
        } else {
            // Single field
            return detail::GetField<ValueType>(*msg, field);
        }
    }
};

// ============================================================================
// Struct wrapper with automatic encoding/decoding
// ============================================================================

template<typename T, typename Schema>
class ProtobufStruct {
private:
    Schema schema_;
    
public:
    template<typename... Args>
    ProtobufStruct(Args&&... args) : schema_(std::forward<Args>(args)...) {}
    
    std::vector<uint8_t> encode(const T& obj) const {
        return obj.encode_with(schema_);
    }
    
    T decode(const std::vector<uint8_t>& buffer) const {
        return T::decode_with(schema_, buffer);
    }
    
    const Schema& schema() const { return schema_; }
};

// ============================================================================
// Example usage - Define your struct
// ============================================================================

struct Person {
    std::string name;
    int32_t id;
    std::vector<std::string> emails;
    bool active;
    
    // Define schema inline
    using Schema = MessageSchema
        Field<std::string, 1>,
        Field<int32_t, 2>,
        RepeatedField<std::vector<std::string>, 3>,
        Field<bool, 4>
    >;
    
    static constexpr auto MakeSchema() {
        return Schema("Person",
            Field<std::string, 1>("name"),
            Field<int32_t, 2>("id"),
            RepeatedField<std::vector<std::string>, 3>("emails"),
            Field<bool, 4>("active")
        );
    }
    
    // Encode using schema
    std::vector<uint8_t> encode_with(const Schema& schema) const {
        return schema.encode(name, id, emails, active);
    }
    
    // Decode using schema
    static Person decode_with(const Schema& schema, 
                              const std::vector<uint8_t>& buffer) {
        auto [name, id, emails, active] = 
            schema.decode<std::string, int32_t, std::vector<std::string>, bool>(buffer);
        return Person{name, id, emails, active};
    }
};

// ============================================================================
// Even simpler: CRTP base class for automatic codec
// ============================================================================

template<typename Derived>
struct ProtobufSerializable {
    std::vector<uint8_t> encode() const {
        static auto schema = Derived::MakeSchema();
        return static_cast<const Derived*>(this)->encode_with(schema);
    }
    
    static Derived decode(const std::vector<uint8_t>& buffer) {
        static auto schema = Derived::MakeSchema();
        return Derived::decode_with(schema, buffer);
    }
};

// Now Person can just inherit and get encode/decode for free
struct SimplePerson : ProtobufSerializable<SimplePerson> {
    std::string name;
    int32_t id;
    std::vector<std::string> emails;
    bool active;
    
    using Schema = MessageSchema
        Field<std::string, 1>,
        Field<int32_t, 2>,
        RepeatedField<std::vector<std::string>, 3>,
        Field<bool, 4>
    >;
    
    static constexpr auto MakeSchema() {
        return Schema("Person",
            Field<std::string, 1>("name"),
            Field<int32_t, 2>("id"),
            RepeatedField<std::vector<std::string>, 3>("emails"),
            Field<bool, 4>("active")
        );
    }
    
    std::vector<uint8_t> encode_with(const Schema& schema) const {
        return schema.encode(name, id, emails, active);
    }
    
    static SimplePerson decode_with(const Schema& schema, 
                                     const std::vector<uint8_t>& buffer) {
        auto [name, id, emails, active] = 
            schema.decode<std::string, int32_t, std::vector<std::string>, bool>(buffer);
        return SimplePerson{name, id, emails, active};
    }
};

// ============================================================================
// Usage examples
// ============================================================================

int main() {
    std::cout << "=== Example 1: Basic usage ===" << std::endl;
    
    Person person{"John Doe", 12345, {"john@example.com", "j.doe@work.com"}, true};
    
    auto schema = Person::MakeSchema();
    auto encoded = schema.encode(person.name, person.id, person.emails, person.active);
    
    std::cout << "Encoded size: " << encoded.size() << " bytes" << std::endl;
    
    auto decoded = Person::decode_with(schema, encoded);
    std::cout << "Decoded: " << decoded.name << ", ID: " << decoded.id << std::endl;
    
    std::cout << "\n=== Example 2: Using CRTP base class ===" << std::endl;
    
    SimplePerson simple{"Jane Doe", 67890, {"jane@example.com"}, false};
    
    // Just call encode() - no schema needed!
    auto encoded2 = simple.encode();
    std::cout << "Encoded size: " << encoded2.size() << " bytes" << std::endl;
    
    // Just call decode() - no schema needed!
    auto decoded2 = SimplePerson::decode(encoded2);
    std::cout << "Decoded: " << decoded2.name << ", ID: " << decoded2.id << std::endl;
    std::cout << "Active: " << (decoded2.active ? "true" : "false") << std::endl;
    
    return 0;
}