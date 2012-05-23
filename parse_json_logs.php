<?php
error_reporting(E_ALL|E_STRICT);
ini_set('display_errors', 'On');

$in = fopen("php://stdin", "r");
while ($line = fgets($in, 4096)) {
  if (substr($line, -1) !== "\n") {
    bail("Input line longer than 4K");
  }
  $o = json_decode(trim($line));
  // Fuck you, PHP.
  if (json_last_error() !== JSON_ERROR_NONE) {
    bail("Couldn't decode JSON string");
  }

  switch (substr($o->stats->status, 0, 1)) {
  case '1': // Informational
    bail('Status not implemented: ' . $o->stats->status);
  case '2': // Successful
    //echo "OK: {$o->request->uri}\n";
    break;
  case '3': // Redirection
    break;
  case '4': // Client Error
    echo "Fail ({$o->stats->status}): {$o->origin} -> {$o->request->uri}\n";
    //var_export($o->request); echo "\n";
    break;
  case '5': // Server Error
    var_export($o->local);
    break;
  default:
    bail('Undefined status! ' . $o->stats->status);
  }

}


function bail($message, $code = 1) {
  $err = fopen("php://stderr", "a");
  fputs($err, $message);
  die($code);
}