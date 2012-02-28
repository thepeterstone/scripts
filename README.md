# Random Scripts

A collection of scripts and utilities that don't fit anywhere else.

## parse_json_logs.php

Post-processor for JSON logs produced by my `json` log format.

Here's the `LogFormat` directive:

  `LogFormat "{'origin': '%h', 'local': { 'address': '%A', 'port': %p, 'pid': %P }, 'request': { 'uri': '%r', 'time': '%t', 'host': '%{Host}i' }, 'stats': { 'status': %>s, 'time': %T, 'req_size': %I, 'res_size': %O, 'connection': '%X'}}" json`

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
