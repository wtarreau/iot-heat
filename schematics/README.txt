The circuit is purpusely single sided, with all the generic stuff under the
ESP and the project-specific one around, so that adapting it to any other use
case should be easy. Particular care was given to make the default circuit
entirely fit under the ESP so that a programming board could be made to use in
sandwich between the ESP and any other board, with only the programming
connector being available. Less than 0.2mm are left spare between some pads
and some tracks, and tracks are as small as 0.254mm. Engraving and etching
must have a fine precision.

The programming is made using the GPIO and EN pin so that GPIO16 can still be
used with RESET to keep the watchdog operational.

Any classical USB-TTL adapter with the R/C pin configured to send RTS will
work. Most CH340-based ones are configurable. Some FTDI-based adapters
are also compatible. The circuit requires to operate under 3V and provided
by the adapter. It automatically resets the board when asserting RTS, which
is what esptool does when it flashes a firmware image.

