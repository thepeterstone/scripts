<?php
if (!user_is_local()) {
  deny_access();
}

$raw = base64_decode(ifset($_GET['cmd']));
$cmd = escapeshellcmd($raw);
$input = htmlentities($raw);
$output = htmlentities(`$cmd`);
?><!DOCTYPE html>
<html lang="en">
<head>
<style>
fieldset, input {
  font-family: monospace;
  white-space: pre;
}
</style>
</head>

<body>
  <fieldset id="input">$ <?php echo $input; ?></fieldset>
  <fieldset id="output"><?php echo $output; ?></fieldset>
  <form id="f" action="<?php echo $_SERVER['PHP_SELF']; ?>" method="get">
  $ <input type="text" id="cmd" name="cmd" value="<?php echo $input; ?>"><br>
  </form>
</body>

<script type="text/javascript" src="http://static.terst.org/scripts/vendor/jquery.js"></script>
<script type="text/javascript" src="http://static.terst.org/scripts/vendor/jquery.base64.js"></script>
<script type="text/javascript">
$(function() {
  $('#f').submit(function () {
    $('#cmd').val($.base64Encode($('#cmd').val()));
    return true;
  });
  $('#cmd').select();
});
</script>
</html><?php
function ifset(&$test, $default = null) {
    return isset($test) ? $test : $default;
}
function deny_access() {
  header('Location: /');exit;
}
function user_is_local() {
    $ips = explode('\n', `ifconfig|grep 'inet addr'|awk '{print $2}'|awk -F: '{print $2}'`);
    return in_array(ifset($_SERVER['REMOTE_ADDR']), $ips);
}
