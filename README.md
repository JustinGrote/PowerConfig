# PowerConfig
Configure your Script or Module with an overlaying config engine. Uses Microsoft.Extensions.Configuration as a backend.

Users can configure your module or script from a variety of sources: multiple json files, yaml files, command line parameters, environment variables, etc. and this gives you a simple unified and merged key-value pair table for all of those configuration points.

If you have ever used ASP.NET configuration this will seem very familiar because it is the same engine :)

# Demo
Check out [the demo script](./Demo)

## Setup and Json Config Source
![JsonDemo](./images/1-Demo.gif)

## YAML Config Source
![YAMLDemo](./images/2-Yaml.gif)

## Environment Config Source
![EnvDemo](./images/3-Environment.gif)

## Powershell Objects and .psd1 files as Config Source
![PSObjects](./images/4-PSObjects.gif)

## Realtime Info Updates
![Realtime](./images/5-RealTimeUpdates.gif)