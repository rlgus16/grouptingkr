class AgoraConfig {
  /// The Agora App ID for the project.  
  /// Get this from https://console.agora.io/
  static const String appId = 'bab60606e5c6441e98b3ba7edc5e09bb';

  /// Whether to use a token for connection (recommended for production).
  /// For testing, if the App Certificate isn't enabled in the console, token can be null.
  static const bool useTokenServer = false;
}
