# modmon - cable modem monitoring for AsusWRT Merlin - with graphs
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/91af8db9cd354643a8ef6a7117be90fb)](https://www.codacy.com/app/jackyaz/modmon?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jackyaz/modmon&amp;utm_campaign=Badge_Grade)
[![Build Status](https://travis-ci.com/jackyaz/modmon.svg?branch=master)](https://travis-ci.com/jackyaz/modmon)

## v1.0.1
### Updated on 2020-04-21
## About
Track your cable modem's stats (such as signal power levels), on your router. Graphs available on the Addons page of the WebUI.
Currently only the Virgin Media Hub 3.0 is supported.

modmon is free to use under the [GNU General Public License version 3](https://opensource.org/licenses/GPL-3.0) (GPL 3.0).

![Menu UI](https://puu.sh/F4nHO/2cb4951f2d.png)

![Graph example](https://puu.sh/F4nIz/4b076a1e1a.png)

### Supporting development
Love the script and want to support future development? Any and all donations gratefully received!
[**PayPal donation**](https://paypal.me/jackyaz21)

## Supported firmware versions
You must be running firmware Merlin 384.15/384.13_4 or Fork 43E5 (or later) [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/)

## Installation
Using your preferred SSH client/terminal, copy and paste the following command, then press Enter:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/jackyaz/modmon/master/modmon.sh" -o "/jffs/scripts/modmon" && chmod 0755 /jffs/scripts/modmon && /jffs/scripts/modmon install
```

## Usage
To launch the modmon menu after installation, use:
```sh
modmon
```

If this does not work, you will need to use the full path:
```sh
/jffs/scripts/modmon
```

## Updating
Launch modmon and select option u

## Help
Please post about any issues and problems here: [modmon on SNBForums](https://www.snbforums.com/threads/modmon-webui-for-monitoring-cable-modem-stats.61363/)

## FAQs
### I haven't used scripts before on AsusWRT-Merlin
If this is the first time you are using scripts, don't panic! In your router's WebUI, go to the Administration area of the left menu, and then the System tab. Set Enable JFFS custom scripts and configs to Yes.

Further reading about scripts is available here: [AsusWRT-Merlin User-scripts](https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts)

![WebUI enable scripts](https://puu.sh/A3wnG/00a43283ed.png)
