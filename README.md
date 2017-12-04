# orvibo
A simple command line tool written in [Swift](https://swift.org/) for interacting with the [Orvibo S20 WiFi Smart Plug](https://www.amazon.com/Control-Appliances-Anywhere-Automation-Smartphones/dp/B014614Q94).

## Prerequisites

This package uses the orvibo plug library at https://github.com/OllieDay/orvibo.
You need to download, build, and install this library first:

	git clone https://github.com/OllieDay/orvibo.git liborvibo
	mkdir build.liborvibo
	cd build.liborvibo
	cmake ../liborvibo
	make
	sudo make install


## Compiling and Installing

This library uses the [Swift Package Manager](https://swift.org/package-manager/).  To build and install use:

	swift build -c release -Xcc -I/usr/local/include -Xlinker -L/usr/local/lib
	sudo cp -p .build/*/release/orvibo /usr/local/bin

To build using Xcode, use

```
swift package generate-xcodeproj --xcconfig-overrides Package.xcconfig
open orvibo.xcodeproj
```

## Usage

Ensure that `/usr/local/bin` is in your path and that your smart plug is connected to your local wireless
 LAN, then run

	orvibo ac:cf:23:24:25:26

(replace `ac:cf:23:24:25:26` with the actual MAC address of your smart plug.)

You can now issue commands on standard input and will receive status updates on standard output.

### Commands

Valid commands are:

	OFF	turn the plug off
	ON	turn the plug on
	P	"ping" the plug: get the current plug status ("On" or "Off")
	Q	quit

### Command line options

Synopsis:	`orvibo [-b port] [-t seconds] [-u port] <Mac>`
Options:

	-b broadcastPort	the UDP port to broadcast status information on (default: none)
	-t timeout			timeout when trying to connect to the socket (default: none)
	-u listenPort		the UDP to listen on for commands (default: none, stdio only)

#### Example

Broadcast on UDP port `12345`, listen for commands on UDP port `54321`, and try to establish a connection to the smart plug within two seconds (otherwise exit):

	orvibo -b 12345 -t 2 -u 54321 ac:cf:23:24:25:26
