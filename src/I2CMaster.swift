// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import ESP_I2C
import Platform

private let log = Logger(tag: "I2C")

/// Wrapper for an I2C master bus.
///
/// `~Copyable` — owns the bus handle; freed automatically in `deinit`.
/// Declare the bus before any `Device` values so Swift destroys them in
/// reverse order (devices first, bus last) — the required IDF cleanup order.
public struct I2CMasterBus: ~Copyable {
    private let busHandle: i2c_master_bus_handle_t

    /// Create a new I2C master bus. Aborts on failure — intended for boot-time static allocation.
    public init(
        i2cPort: i2c_port_t,
        sdaIoNum: gpio_num_t,
        sclIoNum: gpio_num_t,
        clkConfig: i2c_clock_source_t = I2C_CLK_SRC_DEFAULT,
        glitchIgnoreCnt: UInt8 = 7,
        intrPriority: UInt8 = 0,
        transQueueDepth: UInt8 = 0,
        enableInternalPullup: Bool = true,
        allowPd: Bool = false

    ) {
        var busConfig = i2c_master_bus_config_t(
            i2c_port: i2c_port_num_t(i2cPort.rawValue),
            sda_io_num: sdaIoNum,
            scl_io_num: sclIoNum,
            .init(clk_source: clkConfig),
            glitch_ignore_cnt: glitchIgnoreCnt,
            intr_priority: Int32(intrPriority),
            trans_queue_depth: Int(transQueueDepth),
            flags: .init(enable_internal_pullup: enableInternalPullup ? 1 : 0, allow_pd: allowPd ? 1 : 0))

        var busHandle: i2c_master_bus_handle_t?
        i2c_new_master_bus(&busConfig, &busHandle)
            .abortOnError {
                log.e("Failed to create I2C master bus: \($0.name)")
            }
        guard let busHandle else {
            log.e("Failed to create I2C master bus: bus handle is nil")
            fatalError()
        }
        self.busHandle = busHandle
    }

    deinit {
        _ = i2c_del_master_bus(busHandle)
    }

    /// Add a device to the I2C bus.
    ///
    /// - Returns: A `Device` representing the added device.
    /// - Throws: `Error` on failure.
    public func addDevice(
        deviceAddress: UInt16,
        sclSpeedHz: UInt32 = 100_000,
        devAddrLength: i2c_addr_bit_len_t = I2C_ADDR_BIT_LEN_7,
        sclWaitUs: UInt32 = 0,
        disableAckCheck: Bool = false
    ) throws(Error) -> Device {
        var deviceConfig = i2c_device_config_t(
            dev_addr_length: devAddrLength,
            device_address: deviceAddress,
            scl_speed_hz: sclSpeedHz,
            scl_wait_us: sclWaitUs,
            flags: .init(disable_ack_check: disableAckCheck ? 1 : 0))

        var deviceHandle: i2c_master_dev_handle_t?
        try i2c_master_bus_add_device(busHandle, &deviceConfig, &deviceHandle)
            .throwEspError {
                log.e("Failed to create I2C device: \($0.name)")
            }
        guard let deviceHandle else {
            log.e("Failed to create I2C device: device handle is nil")
            throw Error.espError(ESP_FAIL)
        }
        return Device(deviceHandle: deviceHandle)
    }

    /// Represents a device attached to the I2C master bus.
    ///
    /// `~Copyable` — owns the device handle; removed automatically in `deinit`.
    public struct Device: ~Copyable {
        private let deviceHandle: i2c_master_dev_handle_t

        init(deviceHandle: i2c_master_dev_handle_t) {
            self.deviceHandle = deviceHandle
        }

        deinit {
            _ = i2c_master_bus_rm_device(deviceHandle)
        }

        /// Transmit bytes to the device.
        ///
        /// - Parameters:
        ///   - data: Bytes to send.
        ///   - timeoutMs: Timeout in milliseconds; `-1` means wait forever.
        /// - Throws: `Error` on failure.
        public func transmit(data: [UInt8], timeoutMs: Int32 = -1) throws(Error) {
            try data.withUnsafeBufferPointer { buffer in
                i2c_master_transmit(deviceHandle, buffer.baseAddress, data.count, timeoutMs)
            }
            .throwEspError {
                log.e("I2C transmit failed: \($0.name)")
            }
        }

        /// Receive bytes from the device.
        ///
        /// - Parameters:
        ///   - length: Number of bytes to read.
        ///   - timeoutMs: Timeout in milliseconds; `-1` means wait forever.
        /// - Returns: Received bytes.
        /// - Throws: `Error` on failure.
        public func receive(length: Int, timeoutMs: Int32 = -1) throws(Error) -> [UInt8] {
            var result: esp_err_t = ESP_OK
            let buffer = [UInt8](unsafeUninitializedCapacity: length) { ptr, initializedCount in
                result = i2c_master_receive(deviceHandle, ptr.baseAddress, size_t(length), timeoutMs)
                initializedCount = length
            }
            try result.throwEspError {
                log.e("I2C receive failed: \($0.name)")
            }
            return buffer
        }

        /// Write then read in a single transaction.
        ///
        /// - Parameters:
        ///   - transmitData: Bytes to write.
        ///   - receiveLength: Number of bytes to read after write.
        ///   - timeoutMs: Timeout in milliseconds; `-1` means wait forever.
        /// - Returns: Received bytes.
        /// - Throws: `Error` on failure.
        public func transmitReceive(
            transmitData: [UInt8],
            receiveLength: Int,
            timeoutMs: Int32 = -1
        ) throws(Error) -> [UInt8] {
            var result: esp_err_t = ESP_OK
            let receiveBuffer = [UInt8](unsafeUninitializedCapacity: receiveLength) { rxPtr, initializedCount in
                result = transmitData.withUnsafeBufferPointer { txPtr in
                    i2c_master_transmit_receive(
                        deviceHandle,
                        txPtr.baseAddress, transmitData.count,
                        rxPtr.baseAddress, receiveLength,
                        timeoutMs)
                }
                initializedCount = receiveLength
            }
            try result.throwEspError {
                log.e("I2C transmitReceive failed: \($0.name)")
            }
            return receiveBuffer
        }
    }
}
