# dvr_cli

CLI client for Intelbras DVRs

## Requirements

- Ruby, version >= 3.0
- VLC player
- Unix-like operating system (currently, tested on Mac and Linux)

## How to run

You can run it using:

```bash
ruby dvr_cli -H <dvr_host> --user <your user> --password <your password> -c <channel> [other options]
```

or

```bash
./dvr_cli -H <dvr_host> --user <your user> --password <your password> -c <channel> [other options]
```

## Features

### Realtime monitor

You can watch the realtime camera streaming passing this additional flag:

```bash
-r
```

This will open VNC, and it will show the video stream.

### Playback

You can watch recorded streams using this tool using this flags:

```bash
-P --start <start time> --end <end time>
```

The start and finish time must be in the ISO format, like this:

```bash
-P --start "2024-10-31 21:00:00" --end "2024-10-31 21:30:00"
```

### Bisect

This feature is useful to find when an event occurred. This is done performing a
binary search, providing a timestamp that you know is __before__ the event
happened and a timestamp that you know that is __after__ the timestamp happened,
using these flags:


```bash
-B --start <start time> --end <end time>
```

For example: suppose that there's a car parked in the front of your door and you
want to know when it parked. Also suppose that today is Oct 31, 2024, the clock
is 18h00 and you know that at 12h00 there was no car in front of your door. You
provide these flags:

```bash
-B --start "2024-10-31 12:00:00" --end "2024-10-31 18:30:00"
```

Then it will open VLC in the middle of these two timestamps, that is, 15h. After
quitting VLC, it will be prompted if it is `old` or `new`. In our example, we
type `new` if the car appears in the video, or `old` if doesn't appear. In the
case of `old`, the search proceeds keeping the end time and using using 15h as
the start time; in the case of `new`, the search proceeds keeping the start time
and using 15h as the end time. This will repeat until you reach the event.
