# Random Scripts

A collection of scripts and utilities that don't fit anywhere else.

## clean_js.sh

Quick-and-dirty sed script for reformatting JavaScript.

## remote-shell.php

Provides a minimally-obfuscated, slightly crippled remote shell using PHP and
Javascript.

Features:

  * Commands are Base64 encoded over the wire, so it's not as obviously a shell    
  * Input is escaped using <a href="http://php.net/escapeshellcmd">escapeshellcmd</a>
  * Commands can be sent as a field in a cookie, which is less likely to be logged

Future:

  * provide a shell - i.e., preserve state within a session
  * Use canvas-based interface for full shell features (completion, etc)

    * syntax highlighting
    * automatically link to man pages, etc
  * Use <a href="https://github.com/unconed/TermKit">TermKit</a> serialized over PHP

## server-setup.sh

New server auto-configuration script, suitable for interactive use or as a StackScript for automating provisioning.