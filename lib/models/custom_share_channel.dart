/// 用户自定义的分享通道（包名 + 显示名 + 可选 Activity）
class CustomShareChannel {
  const CustomShareChannel({
    required this.packageName,
    required this.label,
    this.activity,
  });

  final String packageName;
  final String label;
  final String? activity;

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'label': label,
        if (activity != null && activity!.isNotEmpty) 'activity': activity,
      };

  factory CustomShareChannel.fromJson(Map<String, dynamic> json) {
    return CustomShareChannel(
      packageName: json['packageName'] as String? ?? '',
      label: json['label'] as String? ?? '',
      activity: json['activity'] as String?,
    );
  }
}
