use crate::proto;
use prost::Message;
use std::ffi::CString;
use std::os::raw::{c_char, c_int, c_void};
use std::ptr;

extern "C" {
    fn requestApiCall(req: *const c_char, arg_buffer: *mut c_void, arg_len: c_int);
    fn allocateArgBuffer(size: c_int) -> *mut c_void;
}

/// Initialize the library by sending the `init` call to the Nim side.
pub fn init() {
    // Match C++ binding semantics: no payload for init
    unsafe {
        let cname = CString::new("init").unwrap();
        requestApiCall(cname.as_ptr(), std::ptr::null_mut(), 0);
    }
}

/// Send a WakuMessage by wrapping it into the `CallSend` envelope and dispatching it.
pub fn send(msg: &proto::WakuMessage) {
    // Encode WakuMessage into a buffer, then call into Nim
    let mut buf = Vec::with_capacity(msg.encoded_len());
    if let Err(e) = msg.encode(&mut buf) {
        eprintln!("Rust> encode failed for send: {e}");
        return;
    }
    unsafe {
        let arg = allocateArgBuffer(buf.len() as c_int);
        if arg.is_null() {
            eprintln!("Rust> allocateArgBuffer({}) failed", buf.len());
            return;
        }
        ptr::copy_nonoverlapping(buf.as_ptr(), arg as *mut u8, buf.len());
        let cname = CString::new("send").unwrap();
        requestApiCall(cname.as_ptr(), arg, buf.len() as c_int);
    }
}
