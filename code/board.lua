-- board specific stuff, mostly wiring and device addresses :
--   ADC = light sensor  // hardcoded
--   GPIO2  (pin4) = DHT // hardcoded
--   GPIO13 (pin7) = PWM // hardcoded
--   GPIO13 (pin6) = recovery
brd_btn1=PIN_GP12  gpio.mode(brd_btn1, gpio.INPUT, gpio.PULLUP)
