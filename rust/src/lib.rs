mod decoder;
mod error;
mod protocol;
mod serial;

use decoder::{AudioDecoder, DecoderInfo};
use serial::SerialHandle;
use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

// ============================================================
// 全局状态管理 (通过 handle ID 索引)
// ============================================================

static SERIAL_HANDLES: Mutex<Option<Vec<Option<SerialHandle>>>> = Mutex::new(None);
static DECODER_HANDLES: Mutex<Option<Vec<Option<AudioDecoder>>>> = Mutex::new(None);

fn init_serial_store() -> &'static Mutex<Option<Vec<Option<SerialHandle>>>> {
    {
        let mut store = SERIAL_HANDLES.lock().unwrap();
        if store.is_none() {
            *store = Some(Vec::new());
        }
    }
    &SERIAL_HANDLES
}

fn init_decoder_store() -> &'static Mutex<Option<Vec<Option<AudioDecoder>>>> {
    {
        let mut store = DECODER_HANDLES.lock().unwrap();
        if store.is_none() {
            *store = Some(Vec::new());
        }
    }
    &DECODER_HANDLES
}

fn alloc_handle<T>(store: &Mutex<Option<Vec<Option<T>>>>, obj: T) -> *mut std::ffi::c_void {
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

fn take_handle<T>(store: &Mutex<Option<Vec<Option<T>>>>, handle: *mut std::ffi::c_void) -> Option<T> {
    let idx = (handle as usize).wrapping_sub(1);
    let mut store = store.lock().unwrap();
    store.as_mut()?.get_mut(idx)?.take()
}

fn with_handle_mut<T, F, R>(store: &Mutex<Option<Vec<Option<T>>>>, handle: *mut std::ffi::c_void, f: F) -> R
where
    F: FnOnce(&mut T) -> R,
{
    let idx = (handle as usize).wrapping_sub(1);
    let mut store = store.lock().unwrap();
    let slot = store
        .as_mut()
        .and_then(|v| v.get_mut(idx))
        .and_then(|s| s.as_mut());
    f(slot.expect("invalid handle"))
}

// ============================================================
// 串口 FFI 接口
// ============================================================

/// 枚举可用串口，返回 JSON 数组字符串，调用方需用 serial_free_string 释放
#[no_mangle]
pub extern "C" fn serial_enumerate() -> *mut c_char {
    match serial::list_ports_json() {
        Ok(json) => match CString::new(json) {
            Ok(cs) => cs.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => {
            let cs = CString::new("[]").unwrap();
            cs.into_raw()
        }
    }
}

/// 打开串口，返回句柄指针，失败返回 null
#[no_mangle]
pub extern "C" fn serial_open(port_name: *const c_char, baud_rate: u32) -> *mut std::ffi::c_void {
    let name = unsafe {
        if port_name.is_null() {
            return std::ptr::null_mut();
        }
        match CStr::from_ptr(port_name).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return std::ptr::null_mut(),
        }
    };

    match SerialHandle::open(&name, baud_rate) {
        Ok(handle) => alloc_handle(init_serial_store(), handle),
        Err(_) => std::ptr::null_mut(),
    }
}

/// 写数据到串口，返回实际写入字节数，-1 表示错误
#[no_mangle]
pub extern "C" fn serial_write(
    handle: *mut std::ffi::c_void,
    data: *const u8,
    len: u32,
) -> i32 {
    if data.is_null() || handle.is_null() {
        return -1;
    }
    let buf = unsafe { std::slice::from_raw_parts(data, len as usize) };
    with_handle_mut(init_serial_store(), handle, |h| match h.write_all(buf) {
        Ok(n) => n as i32,
        Err(_) => -1,
    })
}

/// 从串口读取数据，返回实际读取字节数，-1 表示错误
#[no_mangle]
pub extern "C" fn serial_read(
    handle: *mut std::ffi::c_void,
    buf: *mut u8,
    len: u32,
    timeout_ms: u32,
) -> i32 {
    if buf.is_null() || handle.is_null() {
        return -1;
    }
    let out = unsafe { std::slice::from_raw_parts_mut(buf, len as usize) };
    with_handle_mut(init_serial_store(), handle, |h| match h.read(out, timeout_ms) {
        Ok(n) => n as i32,
        Err(_) => -1,
    })
}

/// 关闭串口并释放资源
#[no_mangle]
pub extern "C" fn serial_close(handle: *mut std::ffi::c_void) {
    if let Some(h) = take_handle(init_serial_store(), handle) {
        h.close();
    }
}

/// 释放由 Rust 分配的字符串
#[no_mangle]
pub extern "C" fn serial_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

// ============================================================
// 解码器 FFI 接口
// ============================================================

/// 设置 ffmpeg/ffprobe 可执行文件所在目录，必须在 decoder_open 之前调用
#[no_mangle]
pub extern "C" fn decoder_set_ffmpeg_dir(dir: *const c_char) -> i32 {
    if dir.is_null() {
        return -1;
    }
    let path = unsafe {
        match CStr::from_ptr(dir).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return -1,
        }
    };
    decoder::set_ffmpeg_dir(path);
    0
}

/// 打开音频文件，返回解码器句柄，失败返回 null
#[no_mangle]
pub extern "C" fn decoder_open(path: *const c_char, target_rate: u32) -> *mut std::ffi::c_void {
    let path_str = unsafe {
        if path.is_null() {
            return std::ptr::null_mut();
        }
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return std::ptr::null_mut(),
        }
    };

    match AudioDecoder::open(&path_str, target_rate) {
        Ok(dec) => alloc_handle(init_decoder_store(), dec),
        Err(_) => std::ptr::null_mut(),
    }
}

/// 获取音频文件信息，返回 0 成功，-1 失败
#[no_mangle]
pub extern "C" fn decoder_get_info(
    handle: *mut std::ffi::c_void,
    info: *mut DecoderInfo,
) -> i32 {
    if info.is_null() || handle.is_null() {
        return -1;
    }
    with_handle_mut(init_decoder_store(), handle, |dec| {
        let di = unsafe { &mut *info };
        di.sample_rate = dec.info.sample_rate;
        di.total_samples = dec.info.total_samples;
        di.duration_ms = dec.info.duration_ms;
        di.channels = dec.info.channels;
    });
    0
}

/// 流式读取 PCM 数据到 buf (8-bit 无符号)，返回实际采样数；0=EOF, -1=错误
#[no_mangle]
pub extern "C" fn decoder_read(
    handle: *mut std::ffi::c_void,
    buf: *mut u8,
    max_samples: u32,
) -> i32 {
    if buf.is_null() || handle.is_null() {
        return -1;
    }
    let out = unsafe { std::slice::from_raw_parts_mut(buf, max_samples as usize) };
    with_handle_mut(init_decoder_store(), handle, |dec| match dec.read(out, max_samples as usize) {
        Ok(n) => n as i32,
        Err(_) => -1,
    })
}

/// 关闭解码器
#[no_mangle]
pub extern "C" fn decoder_close(handle: *mut std::ffi::c_void) {
    take_handle(init_decoder_store(), handle);
}
