# SwiftI2C

Swift I2C master driver wrapping `esp_driver_i2c`. Swift module name: **`I2C`**.

Depends on: `SwiftPlatform`, `SwiftSupport`, `esp_driver_i2c`

## Files

| File | Role |
|---|---|
| `src/I2CMaster.swift` | `I2CMasterBus` and `I2CMasterBus.Device` — public Swift API |
| `src/i2c.c` / `src/i2c.h` | Thin C wrapper — only `#include <driver/i2c_master.h>` |
| `module.modulemap` | Clang module `ESP_I2C` — umbrella over `src/i2c.h` |

## Public API

```swift
// Create a bus — aborts on failure (boot-time static allocation)
let bus = I2CMasterBus(i2cPort: I2C_NUM_0, sdaIoNum: GPIO_NUM_6, sclIoNum: GPIO_NUM_7)

// Add a device (7-bit address, 100 kHz default) — throws at runtime
let device = try bus.addDevice(deviceAddress: 0x48)

// Transfer
try device.transmit(data: [0x01, 0x02])
let bytes = try device.receive(length: 4)
let response = try device.transmitReceive(transmitData: [0xAB], receiveLength: 2)

// No explicit cleanup — deinit handles it.
// Declare bus before device so Swift destroys them in reverse order (device first) — required IDF order.
```

## Non-obvious patterns

**`~Copyable` + `deinit`** — both `I2CMasterBus` and `I2CMasterBus.Device` are noncopyable. `Bus.deinit` calls `i2c_del_master_bus`; `Device.deinit` calls `i2c_master_bus_rm_device`. Declare `bus` before `device` so Swift destroys them in reverse order (device first), which matches the IDF ownership requirement.

**`@_exported import ESP_I2C`** — re-exports the C module so callers get `i2c_port_t`, `gpio_num_t`, `I2C_NUM_0`, etc. without a separate import.

**`timeoutMs: -1`** — the default for all transfer methods, meaning "wait forever". This value is passed directly to the ESP-IDF API; do not confuse with `nil` / `portMAX_DELAY`.

**No custom C glue** — unlike SwiftGPIO, `i2c.c` contains no runtime logic. It exists solely so the component has a C compilation unit (required by ESP-IDF component registration).
