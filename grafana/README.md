# Grafana Dashboard Configuration for Shelly Power Monitoring

This directory contains example Grafana dashboard configurations for visualizing Shelly device power consumption data.

## Quick Setup

1. **Access Grafana**: Navigate to `http://localhost:3000` (default: admin/admin)

2. **Add InfluxDB Data Source**:
   - Go to Configuration → Data Sources → Add data source
   - Select "InfluxDB"
   - Configure:
     - Query Language: **Flux**
     - URL: `http://influxdb:8086` (or your InfluxDB URL)
     - Organization: `home` (or your org name)
     - Token: Your InfluxDB API token
     - Default Bucket: `power`
   - Click "Save & Test"

3. **Import Dashboard**:
   - Go to Dashboards → Import
   - Upload `shelly-power-dashboard.json`
   - Select your InfluxDB data source
   - Click Import

## Example Flux Queries

### Total Power Consumption (All Devices)

```flux
from(bucket: "power")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] == "power")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> yield(name: "mean")
```

### Power by Device

```flux
from(bucket: "power")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] == "power")
  |> group(columns: ["device"])
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

### Three-Phase Power (L1, L2, L3)

```flux
from(bucket: "power")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] =~ /power_l[123]/)
  |> filter(fn: (r) => r["device"] == "Your_Device_Name")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

### Current Power (Single Stat)

```flux
from(bucket: "power")
  |> range(start: -1m)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] == "power")
  |> last()
  |> group()
  |> sum()
```

### Energy Consumption (kWh over time)

```flux
from(bucket: "power")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] == "power")
  |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
  |> map(fn: (r) => ({ r with _value: r._value / 1000.0 }))
  |> cumulativeSum()
```

### Device Temperature

```flux
from(bucket: "power")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] == "temperature")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

### Peak Power Detection

```flux
from(bucket: "power")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "shelly")
  |> filter(fn: (r) => r["_field"] == "power")
  |> aggregateWindow(every: 1h, fn: max, createEmpty: false)
```

## Dashboard Panel Ideas

### 1. Overview Panel
- **Type**: Stat
- **Query**: Current total power across all devices
- **Thresholds**: Green (0-5000W), Yellow (5000-8000W), Red (>8000W)

### 2. Power Timeline
- **Type**: Time series
- **Query**: Power by device over time
- **Options**: Multi-line chart, fill opacity: 0, line width: 2

### 3. Device Breakdown
- **Type**: Bar gauge
- **Query**: Average power per device in selected time range
- **Options**: Horizontal bars, show values

### 4. Three-Phase Balance
- **Type**: Time series
- **Query**: L1, L2, L3 power for 3EM devices
- **Options**: Different colors per phase

### 5. Energy Cost Calculator
- **Type**: Stat
- **Query**: Total kWh consumed
- **Transformation**: 
  ```
  value * electricity_rate_per_kwh
  ```

### 6. Temperature Monitor
- **Type**: Gauge
- **Query**: Current device temperature
- **Thresholds**: Green (<50°C), Yellow (50-70°C), Red (>70°C)

### 7. Device Status Table
- **Type**: Table
- **Query**: Latest values from all devices
- **Columns**: Device, Power, Temperature, Last Update

### 8. Power Heatmap
- **Type**: Heatmap
- **Query**: Power consumption patterns by hour/day
- **Options**: Color scheme from blue (low) to red (high)

## Alert Rules

### High Power Consumption

```
Alert: High Total Power
Condition: Total power > 10000W for 5 minutes
Notification: Email, Slack, etc.
```

### Device Offline

```
Alert: Device Not Reporting
Condition: No data received for 15 minutes
Notification: Check device connectivity
```

### High Temperature

```
Alert: Device Overheating
Condition: Temperature > 70°C
Notification: Critical - check device immediately
```

## Tips and Best Practices

1. **Use Variables**: Create dashboard variables for device selection
   ```
   from(bucket: "power")
     |> range(start: -7d)
     |> filter(fn: (r) => r["_measurement"] == "shelly")
     |> keyValues(keyColumns: ["device"])
     |> group()
     |> distinct(column: "device")
   ```

2. **Set Appropriate Time Windows**: Use `$__interval` for automatic window sizing

3. **Enable Auto-Refresh**: Set to 10s or 30s for near real-time monitoring

4. **Use Annotations**: Mark significant events (e.g., "AC turned on")

5. **Create Multiple Dashboards**:
   - Overview dashboard (all devices)
   - Per-device detailed dashboards
   - Cost analysis dashboard
   - Comparison dashboard (week over week)

## Troubleshooting

### No Data Showing
- Verify data source configuration
- Check bucket name matches collector config
- Verify time range includes recent data
- Test query in InfluxDB UI first

### Slow Queries
- Increase `aggregateWindow` duration
- Add more specific filters
- Use `|> limit(n: 1000)` for testing
- Consider data retention policies

### Missing Devices
- Verify collector is running and logging data
- Check device names match between collector and queries
- Use InfluxDB Data Explorer to verify data exists

## Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [InfluxDB Flux Language](https://docs.influxdata.com/flux/)
- [Grafana Dashboard Examples](https://grafana.com/grafana/dashboards/)
