/// 协议命令常量
pub mod cmd {
    // 上行 (Host → ESP8266)
    pub const HANDSHAKE: u8 = 0x01;
    pub const FORMAT: u8 = 0x02;
    pub const PLAY: u8 = 0x03;
    pub const STOP: u8 = 0x04;
    pub const DATA: u8 = 0x05;
    pub const VOLUME: u8 = 0x06;
    pub const PING: u8 = 0x07;
    pub const RESET: u8 = 0x08;

    // 下行 (ESP8266 → Host)
    pub const ACK: u8 = 0x80;
    pub const NACK: u8 = 0x81;
    pub const READY: u8 = 0x82;
    pub const ERROR: u8 = 0x83;
}

pub const SYNC1: u8 = 0xAA;
pub const SYNC2: u8 = 0x55;
pub const HEADER_SIZE: usize = 5;
pub const CRC_SIZE: usize = 1;
pub const MAX_PAYLOAD: usize = 1024;

/// CRC8 (Dallas/Maxim, 多项式 0x31 反射)
pub fn crc8(data: &[u8]) -> u8 {
    let mut crc: u8 = 0x00;
    for &byte in data {
        let mut b = byte;
        for _ in 0..8 {
            let mix = (crc ^ b) & 0x01;
            crc >>= 1;
            if mix != 0 {
                crc ^= 0x8C;
            }
            b >>= 1;
        }
    }
    crc
}

/// 构建协议帧，返回完整字节数组
pub fn build_frame(cmd: u8, payload: &[u8]) -> Vec<u8> {
    let len = payload.len();
    assert!(len <= MAX_PAYLOAD, "payload too large");

    let total = HEADER_SIZE + len + CRC_SIZE;
    let mut frame = Vec::with_capacity(total);

    frame.push(SYNC1);
    frame.push(SYNC2);
    frame.push(cmd);
    frame.push((len >> 8) as u8);
    frame.push((len & 0xFF) as u8);
    frame.extend_from_slice(payload);

    let crc = crc8(&frame[2..]); // 计算 CRC8 over CMD + LEN + PAYLOAD
    frame.push(crc);

    frame
}

/// 构建 DATA 帧 (命令 0x05, 载荷 = seq(2字节 LE) + samples)
pub fn build_data_frame(seq: u16, samples: &[u8]) -> Vec<u8> {
    let mut payload = Vec::with_capacity(2 + samples.len());
    payload.push((seq & 0xFF) as u8);
    payload.push((seq >> 8) as u8);
    payload.extend_from_slice(samples);
    build_frame(cmd::DATA, &payload)
}

/// 构建简单命令帧 (无载荷)
pub fn build_cmd_frame(cmd: u8) -> Vec<u8> {
    build_frame(cmd, &[])
}

/// 构建 FORMAT 帧
pub fn build_format_frame(sample_rate: u32, bits_per_sample: u8, channels: u8) -> Vec<u8> {
    let mut payload = Vec::with_capacity(6);
    payload.extend_from_slice(&sample_rate.to_le_bytes());
    payload.push(bits_per_sample);
    payload.push(channels);
    build_frame(cmd::FORMAT, &payload)
}

/// 构建 VOLUME 帧
pub fn build_volume_frame(level: u8) -> Vec<u8> {
    build_frame(cmd::VOLUME, &[level])
}

/// 解析帧，返回 (命令, 载荷)
/// 返回 None 表示帧不完整或校验失败
pub fn parse_frame(frame: &[u8]) -> Option<(u8, Vec<u8>)> {
    if frame.len() < HEADER_SIZE + CRC_SIZE {
        return None;
    }
    if frame[0] != SYNC1 || frame[1] != SYNC2 {
        return None;
    }

    let cmd = frame[2];
    let len = ((frame[3] as usize) << 8) | (frame[4] as usize);

    if frame.len() != HEADER_SIZE + len + CRC_SIZE {
        return None;
    }

    let payload = frame[5..5 + len].to_vec();
    let expected_crc = crc8(&frame[2..5 + len]);
    if frame[5 + len] != expected_crc {
        return None;
    }

    Some((cmd, payload))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_crc8() {
        assert_eq!(crc8(&[0x01, 0x00, 0x00]), 0x4B);
    }

    #[test]
    fn test_build_and_parse_cmd_frame() {
        let frame = build_cmd_frame(cmd::PING);
        let (cmd, payload) = parse_frame(&frame).unwrap();
        assert_eq!(cmd, cmd::PING);
        assert!(payload.is_empty());
    }

    #[test]
    fn test_build_and_parse_data_frame() {
        let samples: Vec<u8> = (0..254).map(|i| (i % 256) as u8).collect();
        let frame = build_data_frame(42, &samples);
        let (cmd, payload) = parse_frame(&frame).unwrap();
        assert_eq!(cmd, cmd::DATA);
        assert_eq!(payload.len(), 2 + 254);
        assert_eq!(payload[0], 42 & 0xFF);
        assert_eq!(payload[1], 42 >> 8);
    }

    #[test]
    fn test_corrupted_frame() {
        let mut frame = build_cmd_frame(cmd::PLAY);
        frame[3] = 0xFF; // corrupt length
        assert!(parse_frame(&frame).is_none());
    }
}
