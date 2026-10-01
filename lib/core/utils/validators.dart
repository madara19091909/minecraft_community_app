class Validators {
  const Validators._();

  static final _username = RegExp(r'^[a-z0-9_]{3,24}$');
  static final _minecraft = RegExp(r'^[A-Za-z0-9_]{3,16}$');

  static String? username(String? v) =>
      (v == null || !_username.hasMatch(v.trim())) ? '3–24 chars: a-z, 0-9, _' : null;

  static String? minecraftUsername(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _minecraft.hasMatch(v.trim()) ? null : '3–16 chars: letters, numbers, _';
  }

  static String? bio(String? v) =>
      (v != null && v.length > 300) ? 'Max 300 characters' : null;

  static String normalizeUrl(String v) {
    final t = v.trim();
    return t.startsWith('http://') || t.startsWith('https://') ? t : 'https://$t';
  }

  static String? optionalUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final u = Uri.tryParse(normalizeUrl(v));
    return (u != null && u.host.contains('.')) ? null : 'Enter a valid link';
  }
}
