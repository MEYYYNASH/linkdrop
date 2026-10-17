class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String? apkUrl;
  final String? exeUrl;
  final String? sha256Apk;
  final String? sha256Exe;
  final DateTime? publishedAt;
  final bool isMandatory;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    this.apkUrl,
    this.exeUrl,
    this.sha256Apk,
    this.sha256Exe,
    this.publishedAt,
    this.isMandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '1.0.0',
      releaseNotes: json['release_notes'] ?? json['body'] ?? 'No release notes provided.',
      apkUrl: json['apk_url'],
      exeUrl: json['exe_url'] ?? json['windows_url'],
      sha256Apk: json['sha256_apk'],
      sha256Exe: json['sha256_exe'],
      publishedAt: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'])
          : null,
      isMandatory: json['mandatory'] ?? false,
    );
  }
}
