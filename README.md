# SwiftI2C

SwiftI2C wraps the ESP-IDF I2C master driver in Embedded Swift. It provides a
type-safe, Swifty interface for configuring an I2C master bus and communicating
with attached devices.

## Features

- Create and delete an I2C master bus (`I2CMasterBus`).
- Add and remove devices by 7-bit or 10-bit address.
- Transmit bytes to a device.
- Receive bytes from a device.
- Combined write-then-read in a single transaction.

## API

All APIs surface ESP-IDF errors as Swift typed throws (`throws(Error)`).

### `I2CMasterBus`

```swift
let bus = I2CMasterBus(
    i2cPort: I2C_NUM_0,
    sdaIoNum: GPIO_NUM_6,
    sclIoNum: GPIO_NUM_7)
```

`init` parameters and their defaults:

| Parameter | Default | Notes |
|---|---|---|
| `i2cPort` | — | Required |
| `sdaIoNum` | — | Required |
| `sclIoNum` | — | Required |
| `clkConfig` | `I2C_CLK_SRC_DEFAULT` | |
| `glitchIgnoreCnt` | `7` | |
| `intrPriority` | `0` | |
| `transQueueDepth` | `0` | |
| `enableInternalPullup` | `true` | |
| `allowPd` | `false` | |

### `I2CMasterBus.Device`

Obtained via `bus.addDevice(deviceAddress:sclSpeedHz:devAddrLength:sclWaitUs:disableAckCheck:)`.

- `transmit(data: [UInt8], timeoutMs: Int32 = -1)`
- `receive(length: Int, timeoutMs: Int32 = -1) -> [UInt8]`
- `transmitReceive(transmitData: [UInt8], receiveLength: Int, timeoutMs: Int32 = -1) -> [UInt8]`

`Device` (and `I2CMasterBus`) are `~Copyable` — no explicit `remove()`/`close()` call is needed; the underlying handle is released automatically in `deinit`.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
