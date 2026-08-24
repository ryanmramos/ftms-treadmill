# Garmin FTMS Treadmill

A Garmin Connect IQ data field for the native Treadmill activity.

The app reads treadmill data from the Bluetooth Low Energy Fitness Machine Service (FTMS). It displays pace, speed, distance for the current connection, incline, and connection state.

## Status

This project is in early development. The first target devices are the Garmin Forerunner 265 and 265S.

## Compatibility

The treadmill must advertise the FTMS service and provide the Treadmill Data characteristic. Support for a specific treadmill still needs to be verified on the hardware.

## Scope

The project only reads treadmill data. It never sends treadmill control commands. It does not support NFC, Apple GymKit, ANT or ANT+, proprietary treadmill protocols, cloud services, or a phone companion app.

## IntelliJ development

The repository includes IntelliJ run configurations under `.idea/runConfigurations`. Open the repository root in IntelliJ and choose a configuration prefixed with `CIQ -` to launch the Connect IQ simulator, build or run the diagnostic app, run diagnostic tests, or build and run the data field.

Build configurations read local settings from `.ciq.local.env`. Copy `.ciq.local.env.example` to `.ciq.local.env` and set `CIQ_DEVELOPER_KEY` to the path of your local Connect IQ developer key. The local file is ignored and the key is not stored in this repository. The configurations target `fr265` by default. Set `CIQ_DEVICE=fr265s` to target the Forerunner 265S.

You can also run the commands from a terminal with `bash tools/ciq.sh help`.

Start `CIQ - Start Simulator` before using a run configuration. The build-and-run configurations expect the simulator to already be open. They target `fr265` by default, so the simulator and `CIQ_DEVICE` must name the same device.

## License

[MIT](LICENSE)
