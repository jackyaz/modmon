# modmon
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/91af8db9cd354643a8ef6a7117be90fb)](https://www.codacy.com/app/jackyaz/modmon?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jackyaz/modmon&amp;utm_campaign=Badge_Grade)
[![Build Status](https://travis-ci.com/jackyaz/modmon.svg?branch=master)](https://travis-ci.com/jackyaz/modmon)

## v1.1.0
### Updated on 2020-10-21
## About
modmon is a tool that tracks your cable modem's stats (such as signal power levels) for AsusWRT Merlin with charts for daily, weekly and monthly summaries.

Currently only the Virgin Media Hub 3.0 is supported.

modmon is free to use under the [GNU General Public License version 3](https://opensource.org/licenses/GPL-3.0) (GPL 3.0).

### Supporting development
Love the script and want to support future development? Any and all donations gratefully received!

[**PayPal donation**](https://paypal.me/jackyaz21)

[**Buy me a coffee**](https://www.buymeacoffee.com/jackyaz)

## Supported firmware versions
You must be running firmware Merlin 384.15/384.13_4 or Fork 43E5 (or later) [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/)

## Installation
Using your preferred SSH client/terminal, copy and paste the following command, then press Enter:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/jackyaz/modmon/master/modmon.sh" -o "/jffs/scripts/modmon" && chmod 0755 /jffs/scripts/modmon && /jffs/scripts/modmon install
```

## Usage
### WebUI
Modmon can be configured via the WebUI, in the Addons section.

### Command Line
To launch the modmon menu after installation, use:
```sh
modmon
```

If this does not work, you will need to use the full path:
```sh
/jffs/scripts/modmon
```

## Screenshots

![WebUI](https://puu.sh/GFIhF/4b2b21c3fd.png)

![CLI UI](https://puu.sh/GFIfe/0ed3bef03d.png)


## Help
Please post about any issues and problems here: [modmon on SNBForums](https://www.snbforums.com/threads/modmon-webui-for-monitoring-cable-modem-stats.61363/)

## FAQs
### I haven't used scripts before on AsusWRT-Merlin
If this is the first time you are using scripts, don't panic! In your router's WebUI, go to the Administration area of the left menu, and then the System tab. Set Enable JFFS custom scripts and configs to Yes.

Further reading about scripts is available here: [AsusWRT-Merlin User-scripts](https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts)

![WebUI enable scripts](https://puu.sh/A3wnG/00a43283ed.png)
