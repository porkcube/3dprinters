# RP2040
My Klipper configs for RP2040 boards using an Adafruit and "generic" ADXL345.  Has some extra "features" like supporting the RP2040's builtin CPU temp sensor and utilizing the onboard LED.

- `adxl-pico.cfg`
    - [Raspberry Pi Pico](https://www.adafruit.com/product/4864) via hardware SPI
        - Used with [Adafruit ADXL345](https://www.adafruit.com/product/1231)
        - when used with above I had to "lift" GND connection, ymmv.
- `adxl-qt.cfg`
   - [Adafruit QT Py RP2040](https://www.adafruit.com/product/4900) via software SPI
       - Used with [Arceli ADXL345](https://www.amazon.com/dp/B07DMZCGP9)
