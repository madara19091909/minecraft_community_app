enum AccountStatus {
  pending,
  active,
  suspended,
  banned;

  static AccountStatus parse(String? value) => AccountStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => AccountStatus.pending,
      );
}
