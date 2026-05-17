mod error;
mod midi;
mod protocol;
mod serial;

use midi::MidiResult;
use serial::SerialHandle;
use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

static SERIAL_HANDLES: Mutex<Option<Vec<Option<SerialHandle>>>> = Mutex::new(None);

fn init_store() -> &'static Mutex<Option<Vec<Option<SerialHandle>>>> {
    {
        let mut store = SERIAL_HANDLES.lock().unwrap();
        if store.is_none() {
            *store = Some(Vec::new());
        }
    }
    &SERIAL_HANDLES
}

fn alloc_handle(store: &Mutex<Option<Vec<Option<SerialHandle>>>>, obj: SerialHandle) -> *mut std::ffi::c_void {
    let mut store = store.lock().unwrap();
    let vec = store.as_mut().unwrap();
    for (i, slot) in vec.iter_mut().enumerate() {
        if slot.is_none() {
            *slot = Some(obj);
            return (i as *mut std::ffi::c_void).wrapping_add(1);
        }
    }
    vec.push(Some(obj));
    ((vec.len() - 1) as *mut std::ffi::c_void).wrapping_add(1)
}

fn take_handle(store: &Mutex<Option<Vec<Option<SerialHandle>>>>, handle: *mut std::ffi::c_void) -> Option<SerialHandle> {
    let idx = (handle as usize).wrapping_sub(1);
    let mut store = store.lock().unwrap();
    store.as_mut()?.get_mut(idx)?.take()
}

fn with_handle_mut<F, R>(store: &Mutex<Option<Vec<Option<SerialHandle>>>>, handle: *mut std::ffi::c_void, f: F) -> R
where F: FnOnce(&mut SerialHandle) -> R,
{
    let idx = (handle as usize).wrapping_sub(1);
    let mut store = store.lock().unwrap();
    let slot = store.as_mut().and_then(|v| v.get_mut(idx)).and_then(|s| s.as_mut());
    f(slot.expect("invalid handle"))
}

#[no_mangle]
pub extern "C" fn serial_enumerate() -> *mut c_char {
    match serial::list_ports_json() {
        Ok(json) => match CString::new(json) { Ok(cs) => cs.into_raw(), Err(_) => std::ptr::null_mut() },
        Err(_) => CString::new("[]").unwrap().into_raw(),
    }
}

#[no_mangle]
pub extern "C" fn serial_open(port_name: *const c_char, baud_rate: u32) -> *mut std::ffi::c_void {
    let name = unsafe {
        if port_name.is_null() { return std::ptr::null_mut(); }
        match CStr::from_ptr(port_name).to_str() { Ok(s) => s.to_string(), Err(_) => return std::ptr::null_mut() }
    };
    match SerialHandle::open(&name, baud_rate) {
        Ok(handle) => alloc_handle(init_store(), handle),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn serial_write(handle: *mut std::ffi::c_void, data: *const u8, len: u32) -> i32 {
    if data.is_null() || handle.is_null() { return -1; }
    let buf = unsafe { std::slice::from_raw_parts(data, len as usize) };
    with_handle_mut(init_store(), handle, |h| match h.write_all(buf) { Ok(n) => n as i32, Err(_) => -1 })
}

#[no_mangle]
pub extern "C" fn serial_read(handle: *mut std::ffi::c_void, buf: *mut u8, len: u32, timeout_ms: u32) -> i32 {
    if buf.is_null() || handle.is_null() { return -1; }
    let out = unsafe { std::slice::from_raw_parts_mut(buf, len as usize) };
    with_handle_mut(init_store(), handle, |h| match h.read(out, timeout_ms) { Ok(n) => n as i32, Err(_) => -1 })
}

#[no_mangle]
pub extern "C" fn serial_close(handle: *mut std::ffi::c_void) {
    if let Some(h) = take_handle(init_store(), handle) { h.close(); }
}

#[no_mangle]
pub extern "C" fn serial_free_string(s: *mut c_char) {
    if !s.is_null() { unsafe { let _ = CString::from_raw(s); } }
}

// ============================================================
// MIDI FFI
// ============================================================

/// 解析 MIDI 文件，返回堆分配的 MidiResult (Dart 侧需用 midi_free_result 释放)
#[no_mangle]
pub extern "C" fn midi_parse_file(path: *const c_char) -> *mut MidiResult {
    let path_str = unsafe {
        if path.is_null() { return std::ptr::null_mut(); }
        match CStr::from_ptr(path).to_str() { Ok(s) => s.to_string(), Err(_) => return std::ptr::null_mut() }
    };
    match midi::parse_midi(&path_str) {
        Ok(result) => Box::into_raw(Box::new(result)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// 释放 midi_parse_file 返回的结果
#[no_mangle]
pub extern "C" fn midi_free_result(ptr: *mut MidiResult) {
    if !ptr.is_null() {
        unsafe {
            let result = Box::from_raw(ptr);
            if !result.notes.is_null() {
                drop(Vec::from_raw_parts(result.notes, result.note_count as usize, result.note_count as usize));
            }
        }
    }
}
