# orvibo
A simple command line tool written in [Swift](https://swift.org/) for interacting with the [Orvibo S20 WiFi Smart Plug](https://www.amazon.com/Control-Appliances-Anywhere-Automation-Smartphones/dp/B014614Q94).

## Prerequisites

This package uses the orvibo plug library at https://github.com/OllieDay/orvibo.
You need to download, build, and install this library first:

```
$ git clone https://github.com/OllieDay/orvibo.git
$ cd orvibo
$ mkdir build && cd build
$ cmake ..
$ make install clean
```

## Compiling

This library uses the [Swift Package Manager](https://swift.org/package-manager/).  To build and install use:

	swift build  -Xcc -I/usr/local/include -Xlinker -L/usr/local/lib
	sudo cp -p .build/debug/orvibo /usr/local/bin

## Usage

Ensure that `/usr/local/bin` is in your path, then run

	orvibo -m ac:cf:12:34:56:78

(replace `ac:cf:12:34:56:78` with the MAC address of your smart plug.)
