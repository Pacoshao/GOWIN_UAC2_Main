UAC2 PWM Standalone File Pack

Project file:
- uac2_pwm_standalone.gprj

Top module:
- top_uac2_pwm (src/custom/top_uac2_pwm.v)

Add all source files under src/ to the new Gowin project.

Required Verilog include paths:
- src/usb_controller
- src/usb_softphy

Constraints:
- constraints/usb2Audio.cst
- constraints/usb2Audio.sdc

Notes:
- This package keeps USB UAC2 protocol/control path and replaces audio output with PWM.
- EP2 (capture) path is stubbed to keep descriptor compatibility.
- AUDIO_PWM_O should be routed to a pin and filtered (RC/LPF) before analog stage.
