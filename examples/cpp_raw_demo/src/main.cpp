#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <thread>

#include "demolib_api.h"
#include "event_dispatcher.h"

using namespace std::chrono_literals;


int main(int argc, char *argv[])
{
    // Initialize Google's protobuf library
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    try
    {
        // Initialize demolib explicitly (following Google Protobuf pattern)
        demolib_initialize();

        EventDispatcher::registerHandler<onReceivedEvent>([](const onReceivedEvent& msg) {
                std::cout << "CPP side>Received message: " << msg.msg().content_topic() <<
                " with payload: " << msg.msg().payload() << std::endl;
            });

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
                                   std::chrono::system_clock::now().time_since_epoch())
                                   .count();
        waku_msg.set_timestamp(current_time);

        // Print info about the message
        std::cout << "CPP side>Sending message with payload: " << waku_msg.payload() << std::endl;
        std::cout << "CPP side>Content topic: " << waku_msg.content_topic() << std::endl;

        // Call the send function with the WakuMessage
        send(waku_msg);

        std::cout << "CPP side>Message sent successfully!" << std::endl;

        std::this_thread::sleep_for(400ms);
        std::cout << "CPP side>Slept 400!" << std::endl;

        send(waku_msg);
        std::cout << "CPP side>2nd Message sent successfully!" << std::endl;

        std::this_thread::sleep_for(10s);
        std::cout << "CPP side>Slept 1500" << std::endl;
    }
    catch (const std::exception &e)
    {
        std::cerr << "Exception: " << e.what() << std::endl;
        // Don't return here - let teardown happen below
    }

    // Cleanup demolib (always called, even on exceptions)
    demolib_teardown();
    
    // Clean up protobuf
    google::protobuf::ShutdownProtobufLibrary();

    return 0;
}