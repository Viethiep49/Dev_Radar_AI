/// Public OAuth config from GET /api/v1/auth/oauth/providers (never contains secrets).
class OAuthProvidersModel {
  final bool googleEnabled;
  final String? googleClientId;
  final bool githubEnabled;
  final String? githubClientId;
  final String? githubRedirectUri;
  final String githubAuthorizeUrl;
  final String githubScope;

  const OAuthProvidersModel({
    required this.googleEnabled,
    this.googleClientId,
    required this.githubEnabled,
    this.githubClientId,
    this.githubRedirectUri,
    required this.githubAuthorizeUrl,
    required this.githubScope,
  });

  factory OAuthProvidersModel.fromJson(Map<String, dynamic> json) {
    final google = json['google'] as Map<String, dynamic>? ?? const {};
    final github = json['github'] as Map<String, dynamic>? ?? const {};
    return OAuthProvidersModel(
      googleEnabled: google['enabled'] as bool? ?? false,
      googleClientId: google['client_id'] as String?,
      githubEnabled: github['enabled'] as bool? ?? false,
      githubClientId: github['client_id'] as String?,
      githubRedirectUri: github['redirect_uri'] as String?,
      githubAuthorizeUrl:
          github['authorize_url'] as String? ?? 'https://github.com/login/oauth/authorize',
      githubScope: github['scope'] as String? ?? 'read:user user:email',
    );
  }
}
