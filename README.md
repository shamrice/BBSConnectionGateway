# BBSCG - BBS Connection Gateway

This is an entry point gateway for a backend BBS. There are multiple ways it can be configured to accept incoming connections and route them to the destination BBS.
  * A telnet BBS that only allows one connection at a time. This program can be used to gracefully handle follow up connections while the BBS is busy as well as show a template file when the destination BBS is currently offline.
  * A multi-user telnet BBS - the single user block can be turned off to use this as a router to the destination BBS for multiple users (**to-do**). An automatic 'offline' template screen or text can be configured when the BBS is offline.
  * Dial up connections to either a single user BBS or multi-user BBS.
  * Dial up connections can also have a whole list of potential BBSes to connect to that are checked for availability when the user connects. This list can also be filtered by the user's connection type. The user is presented with a menued list if more than one configured BBS is online.
  * Dial up connections can also be configured to send out a predetermiend string of bytes to the destination BBS so that it can switch into a more dial up friendly mode if available. This can also be used to help bypass any 'Press Enter' type prompts when connecting the user.

Currently this is being written for use with my Atari 8-bit BBS [Action 8](https://github.com/shamrice/action8bbs) but can be configured for any type of BBS.

## Usage ##
Foreground usage:
```
./script/bbscg
```

Background usage:

*start:*
```
./script/start.sh
```

*stop:*
```
./script/stop.sh
```

## Additional Credits ##
The original idea for this application's single user filtering came from [BusyBBS](https://www.southernamis.com/busybbs) written by John Polka of [The Basement BBS](http://basementbbs.ddns.net:7000/).
