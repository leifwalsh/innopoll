innopoll
========

For a paper, we want to extract some stats out of InnoDB about the insert
buffer. This script eats `SHOW ENGINE INNODB STATUS` output and selects a
few fields we care about.

Usage
-----

    $ ./innopoll.pl [--debug] [--period N] [-u|--user user] [-p|--pass pass] [--host host[:port]]

