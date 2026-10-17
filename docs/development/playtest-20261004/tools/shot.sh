#!/bin/sh
xcrun simctl io E64100C9-43DA-4B8C-996A-2D953A13219C screenshot --type=png /private/tmp/playtest/$1.png >/dev/null 2>&1
sips -Z 1000 -s format jpeg /private/tmp/playtest/$1.png --out /private/tmp/playtest/$1.jpg >/dev/null 2>&1 && rm /private/tmp/playtest/$1.png
echo /private/tmp/playtest/$1.jpg
