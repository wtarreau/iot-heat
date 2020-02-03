-- board specific stuff, mostly wiring and device addresses :
--   ADC = light sensor  // hardcoded
--   GPIO2  (pin4) = ESP12 WiFi LED, inverted
--   GPIO12 (pin6) = recovery
--   GPIO13 (pin7) = PWM
--   GPIO14 (pin5) = DHT
brd_led_inv=1      -- led inverted (connected to vcc)
brd_led=PIN_GP2    gpio.mode(brd_led, gpio.OUTPUT) gpio.write(brd_led, brd_led_inv)
brd_btn1=PIN_GP12  gpio.mode(brd_btn1, gpio.INPUT, gpio.PULLUP)
brd_pwm=PIN_GP13
brd_dht=PIN_GP14
