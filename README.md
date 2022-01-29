# magicdeck

Mission: To create a focused and fun environment for writing, coding, and creating!

2022-01-28 Currently this environment runs on Oculus Quest using the Lovr app inside [my fork of inDeck](https://github.com/weex/indeck)

Features:

* Simple environment with flat ground, realistic skybox of stars
* Text and code editor with toggleable syntax highlighting
* A stack of blocks that can be pushed over, picked up and thrown in moon-like gravity

Requirements:

* Oculus Quest or Quest 2
* [Lovr app](https://lovr.org/downloads) (sideloaded)
* Bluetooth keyboard

Installation:

1. Sideload Lovr app (requires putting Quest in developer mode)
2. Setup adb locally
3. Use adb to sync inDeck fork with `adb push --sync $1/. /sdcard/Android/data/org.lovr.app/files`
4. Sync magicdeck with `adb push --sync $1/. /sdcard/Android/data/org.lovr.app/files/sandbox/`

Then you can go to apps -> Unknown sources -> Lovr app and experience Magic Deck

Development:

1. Fork this repo and optionally fork [inDeck](https://github.com/weex/indeck)
2. Install per above.
3. Create issues in this repo if you run into any problems.
4. If you wish to submit a patch, create a new branch off your fork's `main` and create a pull request, referencing the issue/problem it solves.
