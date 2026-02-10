# Changelog

All notable changes to the Shelly EM Data Collector project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Environment variable support for sensitive configuration values:
  - `INFLUX_URL`, `INFLUX_ORG`, `INFLUX_BUCKET`, `INFLUX_TOKEN` for InfluxDB settings
  - `SHELLY_CLOUD_SERVER`, `SHELLY_CLOUD_TOKEN` for Shelly Cloud settings
- Configuration validation on startup with proper error messages
- Graceful shutdown handling for SIGTERM and SIGINT signals
- Statistics tracking with periodic logging of success rates
- Improved error messages including exception details
- Return value from `Send-ToInflux` function for better error tracking
- Device count logging during device discovery

### Changed
- Enhanced error handling throughout the script
- Log function now handles file write errors gracefully
- Configuration parameters now validated with sensible defaults

### Security
- Environment variables can now be used instead of storing tokens in config.json
- Improved configuration file security recommendations

## [1.0.0] - Previous Release

### Added
- Initial release of Shelly EM Data Collector
- Multi-device support for Shelly EM, PM, and 3EM devices
- Dual collection methods (local network and Shelly Cloud)
- InfluxDB v2 integration
- Docker container support
- Windows service installation
- Telegraf integration
- Health monitoring file generation
- Batch processing for cloud devices
- Comprehensive documentation
