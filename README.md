# SwiftI2C

Swift I2C master driver wrapping ESP-IDF's `esp_driver_i2c`. Exposes `I2CMasterBus` and `I2CMasterBus.Device` for configuring a bus and transmitting/receiving with attached devices. Swift module name: **`I2C`**.

Depends on: `SwiftPlatform`, `SwiftSupport`, `esp_driver_i2c`.

## Usage

```swift
import I2C

let bus = I2CMasterBus(i2cPort: I2C_NUM_0, sdaIoNum: GPIO_NUM_6, sclIoNum: GPIO_NUM_7)
let device = try bus.addDevice(deviceAddress: 0x48)

try device.transmit(data: [0x01, 0x02])
let bytes = try device.receive(length: 4)
let response = try device.transmitReceive(transmitData: [0xAB], receiveLength: 2)
// No explicit cleanup — deinit handles it.
// Declare bus before device so Swift destroys them in reverse order (device first) — required IDF order.
```

See [`CLAUDE.md`](CLAUDE.md) for full API details and non-obvious patterns.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
