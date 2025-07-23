// Include the necessary headers:
// - demolib.h: Contains the Nim library's C interface
// - message.pb.h: Contains the protobuf-generated message classes
#include "demolib.h"
#include "message.pb.h"


/**
 * Encodes a WakuMessage and sends it using the requestApiCall function.
 * This function is to be generated along with protobuf classes to represent API calls
 * 
 * @param waku_msg The WakuMessage to encode and send
 */
void send(const WakuMessage &waku_msg)
{
    // Create a callSend message that wraps the WakuMessage
    // Serialize the message to a string
    auto serialized_msg = std::make_unique<std::string>("");
    if (!waku_msg.SerializeToString(serialized_msg.get()))
    {
        std::cerr << "Failed to serialize message" << std::endl;
        return;
    }

    // Call the Nim library's exec function with the serialized message
    // Cast data() from const unsigned char* to void*
    requestApiCall("Send", reinterpret_cast<void*>(serialized_msg.get()->data()), serialized_msg.get()->size());

    // must release the pointer due we transfer the ownership to the nim library
    serialized_msg.release();
}
