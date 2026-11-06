String bluetoothDeviceKind(String name, {String icon = ''}) {
  final value = '$name $icon'.toLowerCase();
  if (RegExp(r'controller|gamepad|dualsense|dualshock|xbox|8bitdo|gamesir|input-gaming|joy-con').hasMatch(value)) return 'controller';
  if (RegExp(r'headset|headphone|earbud|arctis|wh-?\d|wf-?\d|airpods|buds|fone|jabra|bose|beats|audio-head').hasMatch(value)) return 'headset';
  return 'other';
}
