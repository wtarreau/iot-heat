-- board specific stuff, mostly wiring and device addresses :
--   ADC = light sensor  // hardcoded
--   GPIO2  (pin4) = DHT
--   GPIO13 (pin7) = PWM
--   GPIO12 (pin6) = recovery
brd_dht=PIN_GP2
brd_btn1=PIN_GP12  gpio.mode(brd_btn1, gpio.INPUT, gpio.PULLUP)
brd_pwm=PIN_GP13
