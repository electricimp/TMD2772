#require "TMD2772.class.nut:1.0.0"

const GAIN = 8;

local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Configure the TMD2772 with the default i2c address
als <- TMD2772(i2c);

als.alsSetGain(GAIN);
als.alsSetEnabled(true);

function max(a, ...) {
	local maxSeen = a;
	foreach(elt in vargv) {
		if(elt > maxSeen) {
			maxSeen = elt;
		}
	}

	return maxSeen;
}

// The equation captured below is valid for fluorescent, incandescent, and dimmed incandescent light
function getLux() {
	local c0data = als.alsReadChannel0();
	local c1data = als.alsReadChannel1();

	// Note that this assumes that ALS integration time is configured at the default of 2.73 ms
	local countsPerLux = (2.73 * GAIN) / 20;

	// Calculate lux for fluorescent and incandescent light
	local lux1 = (c0data - 1.75 * c1data) / countsPerLux;

	// Calculate lux for dimmed incandescent light
	local lux2 = (0.63 * c0data - c1data) / countsPerLux;

	// Return the largest possibility
	return max(lux1, lux2, 0);
}

// Print the ambient light strength in units of lux every second
function loop() {
    server.log("Current lux: " + getLux());
    
    imp.wakeup(1, loop);
}

loop();
