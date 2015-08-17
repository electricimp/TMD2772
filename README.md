# TMD2772 Ambient Light and Proximity Sensor

This class allows the Electric Imp to control a [TMD2772](https://ams.com/jpn/content/download/685865/1786649/file/TMD2772WA_Datasheet-[1-20].pdf) ambient light sensor (ALS) and proximity sensor. This module is a low-power I²C sensor with a built-in IR LED for the proximity sensor and fully configurable interrupt generation capabilities. The module also allows for significant configuration of the proximity sensor's IR LED that this class does not yet support.

Note that all methods in this class will throw exceptions upon I²C errors.

You can view the library’s source code on [GitHub](https://github.com/electricimp/TMP2772/tree/v1.0.0).

**To add this library to your project, add** `#require "TMP2772.class.nut:1.0.0"` **to the top of your device code.**

## Example Usage

For an example project that uses the TMD2772 to calculate light intensity in units of lux, see the [Lux Calculator](examples/lux) class.

## Class Usage

### Constructor: TMD2772(*i2c, [address]*)

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| i2c     | [i2c](https://electricimp.com/docs/api/hardware/i2c/) | N/A | The pre-configured I²C bus that the TMD2772 is connected to. |
| address | Integer | 0x72    | The 8-bit* I²C address of the TMD2772. |

**NOTE:** The address listed in the TMD2772 (0x39) is a 7-bit I2C address.

#### Example

```squirrel
#require "TMD2772.class.nut:1.0.0"

local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Configure the TMD2772 with the default i2c address
prox <- TMD2772(i2c);
```

## Class Methods

The methods in the TMD2772 library can be divided into three sections:

- [ALS Methods](#als-methods)
- [Proximity Sensor Methods](#proximity-sensor-methods)
- [General Methods](#general-methods)

### ALS Methods

The TMD2772 has two sensor photodiodes, named channel 0 and channel 1. The channel 0 photodiode is sensitive to both visible and infrared light, while the channel 1 photodiode is primarily sensitive to infrared light. By combining readings from both of these sensors, an approximation of the visible light in units of lux can be obtained.

### alsEnable(*[enabled]*)

Sets whether the ambient light sensor on the device should be powered on to take readings. The default value for *enabled* is `true`.

If both the ALS and proximity sensor are disabled, the internal oscillator on the TMD2772 will also be disabled to conserve power.

**NOTE**: The TMD2772 starts with the ALS disabled.

### setAlsGain(*gain*)

Sets the gain used on the ALS. The gain is a multiplier that controls how much light is required for each unit of the sensor reading. It is typically selected to maximize dynamic range in a given light condition.

The value of *gain* should be one of 1 (default), 8, 16, or 120.

The *setAlsGain* method returns the actual gain that was set.

### alsReadChannel0()

Returns an ALS data reading from channel 0 (infrared and visible light) on the TMD2772. This value will fit in a 16-bit integer and can be scaled by setting the ALS gain.

See [ALS Methods](#als-methods) for a desctiption of the sensor channels available on the TMD2772, and their usage.

### alsReadChannel1()

Returns an ALS data reading from channel 1 (infrared light only) on the TMD2772. This value will fit in a 16-bit integer and can be scaled by setting the ALS gain.

See [ALS Methods](#als-methods) for a desctiption of the sensor channels available on the TMD2772, and their usage.

### alsConfigureInterrupt(*enabled, [lowerThreshold, upperThreshold, persistence]*)

Enables/disables and configures the ALS interrupt system. When enabled, the TMD2772 can assert an interrupt when the ALS reading goes above or below specified values. Additionally, the number of required readings above or below the thresholds before an interrupt is asserted can be set.

Returns the actual persistence set.

### Parameters
| Name           | Type           | Default | Description |
|----------------|----------------|---------|-------------|
| enabled        | Boolean        | N/A     | Whether the TMD2772 should assert interrupts when ALS readings go beyond the thresholds. |
| lowerThreshold | 16-bit Integer | 0       | If ALS readings go below this value, an interrupt will be asserted. |
| upperThreshold | 16-bit Integer | 0       | If ALS readings go above this value, an interrupt will be asserted. |
| persistence    | 4-bit Integer  | 1       | How many consecutive readings must pass the threshold before an interrupt is asserted. For values 1-3, this corresponds directly to the number of consecutive readings required. For values above 3, this value will be rounded down to the nearest multiple of 5. |

#### Example

```squirrel
// Configure interrupt to assert if the ALS reads below 1 or above 10 at least 15 times in a row
prox.alsConfigureInterrupt(true, 1, 10, 15);
```


## Proximity Sensor Methods

### proximityEnable(*[enabled]*)

Sets whether the proximity sensor on the device should be powered on to take readings. The default value for *enabled* is `true`.

If both the ALS and proximity sensor are disabled, the internal oscillator on the TMD2772 will also be disabled to conserve power.

**NOTE**: The TMD2772 starts with the proximity sensor disabled.

### proximityRead()

Returns a proximity sensor reading from the TMD2772. This value will fit in a 16-bit integer.

The TMD2772 can be configured to use either of its two sensor photodiodes for proximity sensing. This method is configured to use channel 1 by default.

### proximityConfigureInterrupt(*enabled, [lowerThreshold, upperThreshold, persistence]*)

Enables/disables and configures the proximity sensor interrupt system. When enabled, the TMD2772 can assert an interrupt when the proximity sensor reading goes above or below specified values. Additionally, the number of required readings above or below the thresholds before an interrupt is asserted can be set.

Returns the actual persistence set (note that this will always be equal to the persistence requested).

#### Parameters
| Name           | Type           | Default | Description |
|----------------|----------------|---------|-------------|
| enabled        | Boolean        | N/A     | Whether the TMD2772 should assert interrupts when proximity sensor readings go beyond the thresholds. |
| lowerThreshold | 16-bit Integer | 0       | If proximity sensor readings go below this value, an interrupt will be asserted. |
| upperThreshold | 16-bit Integer | 0       | If proximity sensor readings go above this value, an interrupt will be asserted. |
| persistence    | 4-bit Integer  | 1       | How many consecutive readings must pass the threshold before an interrupt is asserted. This corresponds directly to the number of consecutive readings required. When 0, an interrupt will be asserted for every ALS reading. |

See usage for [`alsConfigureInterrupt()`](#alsconfigureinterruptenabled-lowerthreshold-upperthreshold-persistence).

## General Methods

### readStatus()

Reads the status register on the TMD2772 and returns a table with the following fields:

| Name                  | Description |
|-----------------------|-------------|
| `PROXIMITY_SATURATED` | A boolean indicating whether the proximity sensor has reached saturation. |
| `PROXIMITY_INTERRUPT` | A boolean indicating whether the device is asserting a proximity interrupt. |
| `ALS_INTERRUPT` | A boolean indicating whether the device is asserting an ALS interrupt. |
| `PROXIMITY_VALID` | A boolean indicating whether an integration cycle has completed on the proximity channel and there is valid data waiting. |
| `ALS_VALID` | A boolean indicating whether an integration cycle has completed on the ALS channels and there is valid data waiting.|

#### Example

```squirrel
// Set up the Imp to be woken from deep sleep by an interrupt on pin 1
hardware.pin1.configure(DIGITAL_IN_WAKEUP);
imp.onidle(function(){
    // Deep sleep for a day
    server.sleepfor(86400);
});


// Put this snippet at the beginning of the device code to be run on wake
local proxStatus = prox.readStatus();
if(proxStatus.ALS_INTERRUPT || proxStatus.PROXIMITY_INTERRUPT) {
    // The Imp was woken by the TMD2772
}
```

### setWait(*waitTime*)

Sets how long the TMD2772 should pause in between sensor readings. This can have significant power implications, as the TMD2772 only consumes around 90 μA during this waiting period. For a more detailed breakdown of how to use wait time for power management, see the TMD2772 datasheet.

The wait time should be given as a float in milliseconds.  The TMD2772 has a precision of 2.73 ms for wait periods up to 698 ms and a precision of 32.76 ms for wait times up to 8353 ms, so this method rounds up to the nearest available wait time and returns the actual wait time set.

#### Example

```squirrel
// Wait for around 8 seconds between each reading
prox.setWait(8000);
```

### setSleepAfterInterrupt(*shouldSleep*)

Sets whether the TMD2772 should enter a sleep state after asserting an interrupt. This may conserve power if the device will not be used for some time after the interrupt is asserted.

### clearInterrupt()

Resets the internal interrupt register after an interrupt has been asserted by the TMD2772. After an interrupt threshold has been reached, the TMD2772 will continue asserting an interrupt until this function is called.

This function clears both ALS and proximity sensor interrupts.

#### Example

```squirrel
// Clear the interrupt after it is received
local interruptPin = hardware.pin1;
interruptPin.configure(DIGITAL_IN_WAKEUP, function() {
    // If the pin was just asserted
    if(interruptPin.read() == 0) {
        // ...Do something...

        // All done - clear the interrupt so another can be generated
        prox.clearInterrupt();
    }
});
```

# License

The TMD2772 class is licensed under the [MIT License](https://github.com/electricimp/TMD2772/blob/master/LICENSE).
