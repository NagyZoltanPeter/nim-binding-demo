#include <iostream>
#include <string>
#include <vector>
#include <chrono>

// Include the necessary headers:
// - demolib.h: Contains the Nim library's C interface
// - message.pb.h: Contains the protobuf-generated message classes
#include "demolib.h"
#include "message.pb.h"

/**
 * Encodes a WakuMessage and sends it using the exec function.
 *
 * @param waku_msg The WakuMessage to encode and send
 */
void sendWakuMessage(const WakuMessage& waku_msg) {
    // Create a callSend message that wraps the WakuMessage
    ::callSend send_msg;
    send_msg.mutable_msg()->CopyFrom(waku_msg);
    
    // Serialize the message
    std::string serialized_msg;
    if (!send_msg.SerializeToString(&serialized_msg)) {
        std::cerr << "Failed to serialize message" << std::endl;
        return;
    }
    
    // Call the Nim library's exec function with the serialized message
    exec("Send", const_cast<void*>(static_cast<const void*>(serialized_msg.data())), serialized_msg.size());
}

int main(int argc, char* argv[]) {
    // Initialize Google's protobuf library
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    try {
        // Create a WakuMessage and populate it with test data
        WakuMessage waku_msg;
        
        // Set payload as bytes (protobuf expects bytes for the payload field)
        std::string payload_str = "Hello from C++!";
        waku_msg.set_payload(payload_str);
        
        // Set other fields
        waku_msg.set_content_topic("test/1/waku/proto");
        waku_msg.set_version(1);
        
        // Optionally set timestamp (current time in milliseconds since epoch)
        int64_t current_time = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
        waku_msg.set_timestamp(current_time);
        
        // Print info about the message
        std::cout << "Sending message with payload: " << waku_msg.payload() << std::endl;
        std::cout << "Content topic: " << waku_msg.content_topic() << std::endl;
        
        // Call the sendWakuMessage function with the WakuMessage
        sendWakuMessage(waku_msg);
        
        std::cout << "Message sent successfully!" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
        return 1;
    }
    
    // Clean up protobuf
    google::protobuf::ShutdownProtobufLibrary();
    
    return 0;
}