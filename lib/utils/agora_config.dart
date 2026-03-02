class AgoraConfig {
  /// The Agora App ID for the project.  
  /// Get this from https://console.agora.io/
  static const String appId = '0c5d61d820954f5ebde75fd0318722c1';

  /// Whether to use a token for connection (recommended for production).
  /// For testing, if the App Certificate isn't enabled in the console, token can be null.
  static const bool useTokenServer = false;
}
