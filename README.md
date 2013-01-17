Nerf Java on OSX on the command line
====================================

This merely disables the Java web plugin for use with Safari/FireFox and
Chrome.

If it can find the Oracle package, it disabled that. If it can find any
plugin at all, it disables that by moving it away. Which kinda breaks the
receipt for it, but makes it easier to revert. Upgrading to a new Java
from Oracle will rewrite the receipt anyway. It just seemed easier.

You _can_ easily turn it back on, but don't do that.
