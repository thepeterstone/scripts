<?php

$in = fopen("php://stdin", "r");
while ($line = fgets($in, 4096)) {
  if (substr($line, -1) !== "\n") {
    bail("Input line longer than 4K");
  }
  $o = json_decode($line);
  if (!$o) {
    bail("Couldn't decode JSON string");
  }
}


function bail($message, $code = 1) {
  $err = fopen("php://stderr", "a");
  fputs($err, $message);
  die($code);
}