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
    auto sizeRequired = waku_msg.ByteSizeLong();
    auto argBuffer = allocateArgBuffer(sizeRequired);

    if (!waku_msg.SerializeToArray(argBuffer, sizeRequired))
    {
        std::cerr << "Failed to serialize message: " << waku_msg.DebugString() << std::endl;
        deallocateArgBuffer(argBuffer);
        return;
    }

    // Call the Nim library's exec function with the serialized message
    // Cast data() from const unsigned char* to void*
    requestApiCall("Send", argBuffer, sizeRequired);

    // buffer memory ownership is transfered to the nim library and will be deallocated after
    // decoded prior to processing the request
}
