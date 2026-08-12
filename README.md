# Garmin FTMS Treadmill

A free, open-source Garmin Connect IQ data field for Garmin’s native Treadmill activity.

It reads standard Bluetooth Low Energy Fitness Machine Service (FTMS) treadmill data and displays treadmill-sourced pace, speed, connected-session distance, incline, and connection state.

## Status

Early development. Initial hardware targets are Garmin Forerunner 265 and Forerunner 265S.

## Compatibility

Designed for treadmills that advertise the Bluetooth FTMS service and provide the Treadmill Data characteristic. Compatibility with a specific treadmill is not guaranteed until tested.

## Safety and scope

This project is read-only: it never sends treadmill control commands. It does not support NFC, Apple GymKit, ANT/ANT+, proprietary treadmill protocols, cloud services, or a phone companion app.

## License

[MIT](LICENSE)