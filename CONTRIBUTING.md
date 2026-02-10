# Contributing to Shelly EM Data Collector

Thank you for your interest in contributing to the Shelly EM Data Collector project! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project follows a standard code of conduct:
- Be respectful and inclusive
- Focus on constructive feedback
- Respect differing viewpoints and experiences
- Accept responsibility and apologize when mistakes are made

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with a clear title and description
3. **Include details**:
   - Your environment (OS, PowerShell version)
   - Shelly device models
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Relevant log excerpts

### Submitting Changes

1. **Fork the repository** to your GitHub account
2. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following the coding standards below
4. **Test thoroughly** with actual Shelly devices if possible
5. **Commit with clear messages**:
   ```bash
   git commit -m "Add feature: brief description"
   ```
6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Create a Pull Request** with:
   - Clear title and description
   - Reference to related issues
   - Summary of changes made
   - Testing performed

## Development Guidelines

### PowerShell Coding Standards

- **Use clear, descriptive names** for variables and functions
- **Follow PowerShell naming conventions**:
  - Functions: `Verb-Noun` format (e.g., `Get-DeviceStatus`)
  - Variables: camelCase (e.g., `$deviceList`)
- **Include comment-based help** for all functions using `<#...#>` blocks
- **Keep functions focused** - each function should do one thing well
- **Use proper error handling** with try-catch blocks
- **Log important events** using the `Log` function

### Code Style

```powershell
# Good example
function Get-DeviceData {
    param(
        [string]$DeviceUrl,
        [int]$Timeout = 5
    )
    
    try {
        $result = Invoke-RestMethod -Uri $DeviceUrl -TimeoutSec $Timeout
        return $result
    } catch {
        Log "Failed to fetch device data: $($_.Exception.Message)"
        return $null
    }
}
```

### Testing

Before submitting:

1. **Test with real devices** if possible
2. **Test different device types** (EM, PM, 3EM)
3. **Test error scenarios**:
   - Network failures
   - Invalid configuration
   - Missing devices
   - InfluxDB unavailable
4. **Verify no breaking changes** to existing functionality
5. **Test deployment methods**:
   - Direct execution
   - Docker (if relevant changes)
   - Windows Service (if relevant changes)

### Documentation

- **Update README.md** if adding features or changing behavior
- **Update CHANGELOG.md** following [Keep a Changelog](https://keepachangelog.com/) format
- **Include inline comments** for complex logic
- **Update example config** if adding new configuration options
- **Add examples** for new features

## Development Setup

### Prerequisites

- PowerShell 7.0 or later
- Docker (for container testing)
- Access to Shelly devices or Shelly Cloud account
- InfluxDB v2 instance (local or remote)

### Local Development

1. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/Shelly-EM-Data-Collector.git
   cd Shelly-EM-Data-Collector
   ```

2. Copy and configure:
   ```bash
   cp config.example.json config.json
   # Edit config.json with your settings
   ```

3. Run the collector:
   ```powershell
   pwsh ./shelly-collector.ps1
   ```

4. Monitor logs:
   ```bash
   tail -f collector.log
   ```

### Docker Development

Build and test container:
```bash
docker build -t shelly-collector-dev .
docker run -it --rm -v $(pwd)/config.json:/app/config.json:ro shelly-collector-dev
```

## Feature Ideas

Here are some areas where contributions would be welcome:

### High Priority
- Unit tests using Pester
- Integration tests with mock InfluxDB
- Automated CI/CD pipeline
- Additional device type support

### Medium Priority
- Prometheus metrics exporter
- MQTT support as alternative to InfluxDB
- Configuration file hot-reload
- Advanced retry logic with exponential backoff

### Nice to Have
- Web UI for configuration and monitoring
- Built-in Grafana dashboard templates
- Support for InfluxDB v1
- Support for other time-series databases

## Adding New Device Types

To add support for a new Shelly device type:

1. **Update `Get-CloudDevices`** to include the device type in the filter
2. **Update `Convert-ToInfluxLine`** to parse the device's status format
3. **Test with the actual device**
4. **Document** the new device type in README.md
5. **Add example** to config.example.json if needed

Example:
```powershell
# In Get-CloudDevices
if ($dev.type -match "EM|PM|3EM|NewType") {

# In Convert-ToInfluxLine
elseif ($Status.new_device_property) {
    # Handle new device type
    $totalPower += [double]$Status.new_device_property
}
```

## Performance Considerations

When contributing, consider:

- **Minimize API calls** - use batch operations when possible
- **Efficient data structures** - avoid unnecessary loops or copies
- **Timeout values** - balance responsiveness vs reliability
- **Memory usage** - avoid storing unnecessary historical data
- **Error isolation** - one device failure shouldn't affect others

## Security Guidelines

- **Never commit secrets** - always use config.json (gitignored)
- **Support environment variables** for sensitive values
- **Validate all inputs** - especially URLs and API tokens
- **Use HTTPS** when available
- **Follow least privilege** principle
- **Document security considerations** for new features

## Questions?

If you have questions about contributing:
- Open an issue with the `question` label
- Check existing issues and pull requests
- Review the project documentation

Thank you for contributing! 🚀
