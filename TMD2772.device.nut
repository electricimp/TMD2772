// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class TMD2772 {
    
    static COMMAND_AUTOINCREMENT = 0xA0;
    static COMMAND_INTERRUPT_CLEAR = 0xE7;
    
    static REGISTER_ENABLE = 0x00;
    static REGISTER_WAIT = 0x03;
    static REGISTER_AILTL = 0x04;
    static REGISTER_AILTH = 0x05;
    static REGISTER_AIHTL = 0x06;
    static REGISTER_AIHTH = 0x07
    static REGISTER_PILTL = 0x08;
    static REGISTER_PILTH = 0x09;
    static REGISTER_PIHTL = 0x0A;
    static REGISTER_PIHTH = 0x0B;
    static REGISTER_PERSISTENCE = 0x0C;
    static REGISTER_CONFIG = 0x0D;
    static REGISTER_CONTROL = 0x0F;
    static REGISTER_STATUS = 0x13;
    static REGISTER_C0DATA = 0x14;
    static REGISTER_C1DATA = 0x16;
    static REGISTER_PROXDATA = 0x18;
    
    _i2c = null;
    _address = null;
    
    // -------------------- Device-level Methods -------------------- //
    
    function constructor(i2c, address=0x39) {
        _i2c = i2c;
        _address = address << 1;
    }
    
    function readStatus() {
        local status = _readRegister(REGISTER_STATUS);
        return {
            "PROXIMITY_SATURATED"   : status & 0x40 ? true : false,
            "PROXIMITY_INTERRUPT"   : status & 0x20 ? true : false,
            "ALS_INTERRUPT"         : status & 0x10 ? true : false,
            "PROXIMITY_VALID"       : status & 0x02 ? true : false,
            "ALS_VALID"             : status & 0x01 ? true : false
        };
    }
    
    function setSleepAfterInterrupt(shouldSleep) {
        local value = shouldSleep ? 0x40 : 0x00;
        _writeRegister(REGISTER_ENABLE, value, 0x40);
    }
    
    function setWait(waitTime, shouldMakeLong=false) {
        if(waitTime == 0) {
            _writeRegister(REGISTER_ENABLE, 0x00, 0x08);
        } else {
            // First write base multiplier
            _writeRegister(REGISTER_ENABLE, 0x08, 0x08);
            local waitValue = 256 - waitTime;
            _writeRegister(REGISTER_WAIT, waitValue);
            
            // Then write long (12x) multiplier
            local makeLongValue = shouldMakeLong ? 0x02 : 0x00;
            _writeRegister(REGISTER_CONFIG, makeLongValue, 0x02);
        }
    }
    
    function clearInterrupt() {
        local writeError = _i2c.write(_address, COMMAND_INTERRUPT_CLEAR.tochar());
        if(writeError != 0) {
            throw "i2c error: " + writeError;
        }
    }

    // -------------------- ALS-Specific Methods -------------------- //
    
    function alsSetEnabled(shouldEnable) {
        // First generate a naive value assuming that proximity sensing is disabled
        local value = shouldEnable ? 0x03 : 0x00;
        
        // Next, use the mask to prevent chip shutdown if we are disabling ALS but proximity is enabled
        local proximityEnabled = _readRegister(REGISTER_ENABLE);
        local mask = proximityEnabled & 0x04 ? 0x02 : 0x03;
        _writeRegister(REGISTER_ENABLE, value, mask);
    }
    
    function alsSetGain(gain) {
        local translatedGain;
        if(gain >= 120) {
            translatedGain = 0x03;
        } else if(gain >= 16) {
            translatedGain = 0x02;
        } else if(gain >= 8) {
            translatedGain = 0x01;
        } else {
            translatedGain = 0x00;
        }
        _writeRegister(REGISTER_CONTROL, translatedGain, 0x03);
    }
    
    function alsConfigureInterrupt(enabled, lowerThreshold=0x00, upperThreshold=0x00, persistence=1) {
        local enableValue = enabled ? 0x10 : 0x00;
        _writeRegister(REGISTER_ENABLE, enableValue, 0x10);
        
        // Write low threshold
        _writeRegister(REGISTER_AILTL, lowerThreshold & 0xFF);
        _writeRegister(REGISTER_AILTH, lowerThreshold >> 8);
        
        // Write high threshold
        _writeRegister(REGISTER_AIHTL, upperThreshold & 0xFF);
        _writeRegister(REGISTER_AIHTH, upperThreshold >> 8);

        // Write persistence filter
        local translatedPersistence = persistence;
        if(persistence > 3) {
            translatedPersistence = (persistence / 5) + 3;
        }
        _writeRegister(REGISTER_PERSISTENCE, translatedPersistence, 0x0F);
    }
    
    function alsReadChannel0() {
        return _readRegister(REGISTER_C0DATA, true);
    }
    
    function alsReadChannel1() {
        return _readRegister(REGISTER_C1DATA, true);
    }
    
    // -------------------- Proximity-Specific Methods -------------------- //

    function proximitySetEnabled(shouldEnable) {
        // Select a diode to sense with if none is already selected
        local selectedDiode = _readRegister(REGISTER_CONTROL);
        if((selectedDiode & 0x30) == 0) {
            _writeRegister(REGISTER_CONTROL, 0x20, 0x30);
        }
        
        // First generate a naive value assuming that the ALS is disabled
        local value = shouldEnable ? 0x05 : 0x00;
        
        // Next, use the mask to prevent chip shutdown if we are disabling proximity but the ALS is enabled
        local alsEnabled = _readRegister(REGISTER_ENABLE);
        local mask = alsEnabled & 0x02 ? 0x04 : 0x05;
        _writeRegister(REGISTER_ENABLE, value, mask);
    }
    
    function proximityRead() {
        return _readRegister(REGISTER_PROXDATA, true);
    }
    
    function proximityConfigureInterrupt(enabled, lowerThreshold=0x00, upperThreshold=0x00, persistence=1) {
        local enableValue = enabled ? 0x20 : 0x00;
        _writeRegister(REGISTER_ENABLE, enableValue, 0x20);

        // Write low threshold
        _writeRegister(REGISTER_PILTL, lowerThreshold & 0xFF);
        _writeRegister(REGISTER_PILTH, lowerThreshold >> 8);
        
        // Write high threshold
        _writeRegister(REGISTER_PIHTL, upperThreshold & 0xFF);
        _writeRegister(REGISTER_PIHTH, upperThreshold >> 8);

        // Write persistence filter
        _writeRegister(REGISTER_PERSISTENCE, persistence << 4, 0xF0);
    }
    
    // -------------------- PRIVATE METHODS -------------------- //
    
    // Takes an integer register address
    // If twoBytes is true, the register following the provided register will be interpreted as the high half of a 16-bit number
    function _readRegister(register, twoBytes=false) {
        local command = COMMAND_AUTOINCREMENT | register;
        
        // First put the target address in the command register
        local writeError = _i2c.write(_address, command.tochar());
        if(writeError != 0) {
            throw "i2c error: " + writeError;
        }
        
        // Then read the data at the address
        local result = _i2c.read(_address, "", twoBytes ? 2 : 1);
        if(result == null) {
            throw "i2c error: " + _i2c.readerror();
        }
        
        if(twoBytes) {
            return (result[1] << 8) | result[0];
        } else {
            return result[0];
        }
    }
    
    // Takes an integer register address and 1-byte integer value
    // If mask is set, will only write values with 1's
    function _writeRegister(register, value, mask=0xFF) {
        local previousValue = mask == 0xFF ? 0x00 : _readRegister(register);
        local newValue = (previousValue & ~mask) | (value & mask);
        
        local command = COMMAND_AUTOINCREMENT | register;
        local writeError = _i2c.write(_address, format("%c%c", command, newValue));
        if(writeError != 0) {
            throw "i2c error: " + writeError;
        }
    }
}

