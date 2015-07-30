# TMD2772 Ambient Light and Proximity Sensor

This class allows the Electric Imp to control a [TMD2772](https://ams.com/jpn/content/download/685865/1786649/file/TMD2772WA_Datasheet-[1-20].pdf) ambient light sensor (ALS) and proximity sensor.  This module is a low-power I²C sensor with a built-in IR LED for the proximity sensor and fully configurable interrupt generation capabilities.  The module also allows for significant configuration of the proximity sensor's IR LED that this class does not yet support.

Note that all methods in this class will throw exceptions upon I²C errors.

## Constructor: TMD2772(*i2c, [address]*)

### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| i2c     | [i2c] (https://electricimp.com/docs/api/hardware/i2c/) | N/A | The pre-configured I²C bus that the TMD2772 is connected to. |
| address | Integer | 0x39    | The I²C address of the TMD2772. |

### Usage

```squirrel
#require "TMD2772.class.nut:1.0.0"

local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Configure the TMD2772 with the default i2c address
prox <- TMD2772(i2c);
```

## readStatus()

Reads the status register on the TMD2772 and returns a table with the following fields:

| Name                  | Description |
|-----------------------|-------------|
| `PROXIMITY_SATURATED` | A boolean indicating whether the proximity sensor has reached saturation. |
| `PROXIMITY_INTERRUPT` | A boolean indicating whether the device is asserting a proximity interrupt. |
| `ALS_INTERRUPT` | A boolean indicating whether the device is asserting an ALS interrupt. |
| `PROXIMITY_VALID` | A boolean indicating whether an integration cycle has completed on the proximity channel and there is valid data waiting. |
| `ALS_VALID` | A boolean indicating whether an integration cycle has completed on the ALS channels and there is valid data waiting.|


### Usage

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

## setWait(*waitTime, [shouldMakeLong]*)

Sets how long the TMD2772 should pause in between sensor readings.  This can have significant power implications, as the TMD2772 only consumes around 90 μA during this waiting period.  For a more detailed breakdown of how to use wait time for power management, see the TMD2772 datasheet.

### Parameters
| Name           | Type          | Default | Description |
|----------------|---------------|---------|-------------|
| waitTime       | 8-Bit Integer | N/A     | A multiplier to set the length of the pause.  This parameter is multiplied by 2.73 ms for the actual pause time unless *shouldMakeLong* is true. |
| shouldMakeLong | Boolean       | false   | Whether the *waitTime* parameter should instead be multiplied by 32.76 ms (a 12x increase) to determine the pause time. |

### Usage

```squirrel
// Wait for 8.4 seconds between each reading
prox.setWait(255, true);
```

## setSleepAfterInterrupt(*shouldSleep*)

Sets whether the TMD2772 should enter a sleep state after asserting an interrupt.  This may conserve power if the device will not be used for some time after the interrupt is asserted.

## clearInterrupt()

Resets the internal interrupt register after an interrupt has been asserted by the TMD2772.  After an interrupt threshold has been reached, the TMD2772 will continue asserting an interrupt until this function is called.

This function clears both ALS and proximity sensor interrupts.

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

## alsSetEnabled(*shouldEnable*)

Sets whether the ambient light sensor on the device should be powered on to take readings.  The TMD2772 starts with the ALS disabled.

If both the ALS and proximity sensor are disabled, the internal oscillator on the TMD2772 will also be disabled to conserve power.

## setAlsGain(*gain*)

Sets the gain used on the ALS.  The gain is a multiplier that controls how much light is required for each unit of the sensor reading. It is typically selected to maximize dynamic range in a given light condition.

The value of *gain* should be one of 1, 8, 16, or 120.  This value defaults to 1.

## alsReadChannel0()

Returns an ALS data reading from channel 0 on the TMD2772.  This value will fit in a 16-bit integer and can be scaled by setting the ALS gain.

The TMD2772 has two sensor photodiodes, named channel 0 and channel 1.  The channel 0 photodiode is sensitive to both visible and infrared light, while the channel 1 photodiode is primarily sensitive to infrared light.  By combining readings from both of these sensors, an approximation of the visible light in units of lux can be obtained.

### Usage

```squirrel
// TODO: add a section for the lux equation
```

## alsReadChannel1()

Returns an ALS data reading from channel 1 on the TMD2772.  This value will fit in a 16-bit integer and can be scaled by setting the ALS gain.

See [`alsReadChannel0()`](#alsreadchannel0) for a description of the sensor channels on the TMD2772 and their usage.

## alsConfigureInterrupt(*enabled, [lowerThreshold, upperThreshold, persistence]*)

Enables/disables and configures the ALS interrupt system.  When enabled, the TMD2772 can assert an interrupt when the ALS reading goes above or below specified values.  Additionally, the number of required readings above or below the thresholds before an interrupt is asserted can be set.

### Parameters
| Name           | Type           | Default | Description |
|----------------|----------------|---------|-------------|
| enabled        | Boolean        | N/A     | Whether the TMD2772 should assert interrupts when ALS readings go beyond the thresholds. |
| lowerThreshold | 16-bit Integer | 0       | If ALS readings go below this value, an interrupt will be asserted. |
| upperThreshold | 16-bit Integer | 0       | If ALS readings go above this value, an interrupt will be asserted. |
| persistence    | 4-bit Integer  | 1       | How many consecutive readings must pass the threshold before an interrupt is asserted.  For values 1-3, this corresponds directly to the number of consecutive readings required.  For values above 3, this value is calculated as `value = (persistence - 3) * 5` to determine the number of consecutive readings required.  When 0, an interrupt will be asserted for every ALS reading. |

### Usage

```squirrel
// Configure interrupt to assert if the ALS reads below 1 or above 10 at least 15 times in a row
prox.alsConfigureInterrupt(true, 1, 10, 5);
```

## proximitySetEnabled(*shouldEnable*)

Sets whether the proximity sensor on the device should be powered on to take readings.  The TMD2772 starts with the proximity sensor disabled.

If both the ALS and proximity sensor are disabled, the internal oscillator on the TMD2772 will also be disabled to conserve power.

## proximityRead()

Returns a proximity sensor reading from the TMD2772.  This value will fit in a 16-bit integer.

The TMD2772 can be configured to use either of its two sensor photodiodes for proximity sensing.  This method is configured to use channel 1 by default.

## proximityConfigureInterrupt(*enabled, [lowerThreshold, upperThreshold, persistence]*)

Enables/disables and configures the proximity sensor interrupt system.  When enabled, the TMD2772 can assert an interrupt when the proximity sensor reading goes above or below specified values.  Additionally, the number of required readings above or below the thresholds before an interrupt is asserted can be set.

### Parameters
| Name           | Type           | Default | Description |
|----------------|----------------|---------|-------------|
| enabled        | Boolean        | N/A     | Whether the TMD2772 should assert interrupts when proximity sensor readings go beyond the thresholds. |
| lowerThreshold | 16-bit Integer | 0       | If proximity sensor readings go below this value, an interrupt will be asserted. |
| upperThreshold | 16-bit Integer | 0       | If proximity sensor readings go above this value, an interrupt will be asserted. |
| persistence    | 4-bit Integer  | 1       | How many consecutive readings must pass the threshold before an interrupt is asserted.  This corresponds directly to the number of consecutive readings required.  When 0, an interrupt will be asserted for every ALS reading. |

### Usage

See usage for [`alsConfigureInterrupt()`](#alsconfigureinterruptenabled-lowerthreshold-upperthreshold-persistence).

# License

The TMD2772 class is licensed under the [MIT License](./LICENSE).
