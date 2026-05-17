use crate::error::Result;
use serialport::{available_ports, DataBits, FlowControl, Parity, SerialPort, StopBits};
use std::io::{Read, Write};
use std::time::Duration;

pub struct SerialHandle {
    port: Box<dyn SerialPort>,
}

impl SerialHandle {
    pub fn open(port_name: &str, baud_rate: u32) -> Result<Self> {
        let port = serialport::new(port_name, baud_rate)
            .data_bits(DataBits::Eight)
            .stop_bits(StopBits::One)
            .parity(Parity::None)
            .flow_control(FlowControl::None)
            .timeout(Duration::from_millis(50))
            .open_native()?;
        Ok(SerialHandle { port: Box::new(port) })
    }

    pub fn write_all(&mut self, data: &[u8]) -> Result<usize> {
        let written = self.port.write(data)?;
        self.port.flush()?;
        Ok(written)
    }

    pub fn read(&mut self, buf: &mut [u8], timeout_ms: u32) -> Result<usize> {
        self.port
            .set_timeout(Duration::from_millis(timeout_ms as u64))?;
        self.port.read(buf).map_err(Into::into)
    }

    pub fn close(self) {
        drop(self.port);
    }
}

/// 枚举可用串口，返回 JSON 数组字符串
pub fn list_ports_json() -> Result<String> {
    let ports = available_ports()?;
    let mut json = String::from("[");
    for (i, p) in ports.iter().enumerate() {
        if i > 0 { json.push(','); }
        json.push_str(&format!(
            r#"{{"name":"{}","description":"{:?}"}}"#,
            p.port_name.replace('\\', "\\\\").replace('"', "\\\""),
            p.port_type,
        ));
    }
    json.push(']');
    Ok(json)
}
