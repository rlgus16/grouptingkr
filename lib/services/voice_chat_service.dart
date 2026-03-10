import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:audio_session/audio_session.dart';
import '../utils/agora_config.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isManual) async {}

  @override
  void onNotificationButtonPressed(String id) {}
}

class VoiceChatService extends ChangeNotifier {
  RtcEngine? _engine;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  String? _activeChatroomId;
  String? get activeChatroomId => _activeChatroomId;

  // Track presence ref so we can explicitly cancel onDisconnect on intentional leave
  DatabaseReference? _activePresenceRef;

  bool _isVoiceChatActive = false;
  bool get isVoiceChatActive => _isVoiceChatActive;

  bool _isJoinedChannel = false;
  bool get isJoinedChannel => _isJoinedChannel;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = true;
  bool get isSpeakerOn => _isSpeakerOn;

  Map<int, bool> _remoteUsers = {};
  Map<int, bool> get remoteUsers => _remoteUsers;

  Future<void> initAgoraAsListener(String chatroomId, String actualUserId, int agoraUid, List<String> blockedIds) async {
    if (_engine != null && _activeChatroomId == chatroomId) {
      // Already initialized for this room
      return;
    }

    _activeChatroomId = chatroomId;
    
    // Initialize & Start Foreground Task
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'voice_chat_channel',
        channelName: 'Voice Chat Service',
        channelDescription: 'Keeps voice chat alive in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Groupting',
        notificationText: 'Voice Chat in progress',
        callback: startCallback,
      );
    }
    
    // Configure iOS AudioSession
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Set up Firebase Realtime Database Presence
    final presenceRef = _rtdb.ref('.info/connected');
    final userStatusRef = _rtdb.ref('voiceChatPresence/$chatroomId/$actualUserId');

    // Track the presence ref so we can cancel onDisconnect on intentional leave
    _activePresenceRef = userStatusRef;

    presenceRef.onValue.listen((event) {
      if (event.snapshot.value == false) {
        return;
      }
      userStatusRef.onDisconnect().set({
        'status': 'offline',
        'lastChanged': ServerValue.timestamp,
        'chatroomId': chatroomId,
        'userId': actualUserId,
        'agoraUid': agoraUid,
      }).then((_) {
        // When connected successfully, set online status
        userStatusRef.set({
          'status': 'online',
          'lastChanged': ServerValue.timestamp,
          'chatroomId': chatroomId,
          'userId': actualUserId,
          'agoraUid': agoraUid,
        });
      });
    });

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            _isJoinedChannel = true;
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) async {
            _remoteUsers[remoteUid] = true;
            
            bool isRemoteUserBlocked = false;
            for (String blockedId in blockedIds) {
              if (blockedId.hashCode == remoteUid) {
                isRemoteUserBlocked = true;
                break;
              }
            }

            if (isRemoteUserBlocked) {
              await _engine!.muteRemoteAudioStream(
                uid: remoteUid,
                mute: true,
              );
            }
            notifyListeners();
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            _remoteUsers.remove(remoteUid);
            notifyListeners();
          },
        ),
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      
      String rtcToken = '';
      if (AgoraConfig.useTokenServer) {
        try {
          final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateAgoraToken');
          final result = await callable.call(<String, dynamic>{
            'channelName': chatroomId,
            'uid': agoraUid,
            'role': 'broadcaster', // Requesting broadcaster so they can switch roles later
          });
          rtcToken = result.data['token'] as String;
        } catch (e) {
          debugPrint('Error fetching Agora token: $e');
        }
      }

      await _engine!.joinChannel(
        token: rtcToken,
        channelId: chatroomId,
        uid: agoraUid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: true,
        ),
      );

      _isVoiceChatActive = false;
      _isMuted = false;
      _isSpeakerOn = true;
      notifyListeners();

    } catch (e) {
      debugPrint('Agora Listener Init Error: $e');
    }
  }

  Future<bool> joinAsBroadcaster(int currentUid) async {
    try {
      if (_engine == null || _activeChatroomId == null || !_isJoinedChannel) return false;

      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();
      
      await _engine!.updateChannelMediaOptions(
        const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

      _isVoiceChatActive = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Agora Broadcaster Join Error: $e');
      return false;
    }
  }

  Future<void> revertToListener() async {
    try {
      if (_engine != null && _isVoiceChatActive) {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            autoSubscribeAudio: true,
            publishMicrophoneTrack: false,
          ),
        );
        await _engine!.disableAudio();
        
        _isVoiceChatActive = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Agora Listener Revert Error: $e');
    }
  }

  /// Cancels the RTDB onDisconnect handler so it won't fire when the
  /// connection eventually closes after an intentional leave.
  /// We do NOT remove the presence node here — the Cloud Function already
  /// removes it in its own cleanup, and removing it ourselves would
  /// re-trigger the Cloud Function causing a double-decrement of participantCount.
  Future<void> _clearPresence() async {
    if (_activePresenceRef == null) return;
    try {
      await _activePresenceRef!.onDisconnect().cancel();
    } catch (e) {
      debugPrint('RTDB Presence Clear Error: $e');
    } finally {
      _activePresenceRef = null;
    }
  }

  Future<void> leaveVoiceChat() async {
    try {
      if (_engine != null) {
        await revertToListener();
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
      }
    } catch (e) {
      debugPrint('Agora Leave Error: $e');
    } finally {
      await FlutterForegroundTask.stopService();
      _activeChatroomId = null;
      _isVoiceChatActive = false;
      _isJoinedChannel = false;
      _isMuted = false;
      _isSpeakerOn = true;
      _remoteUsers.clear();
      notifyListeners();
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_engine != null) {
      _engine!.muteLocalAudioStream(_isMuted);
    }
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    if (_engine != null) {
      _engine!.setEnableSpeakerphone(_isSpeakerOn);
    }
    notifyListeners();
  }

  // A helper method specifically for when the user explicitly leaves the chatroom DB document
  // It handles removing them from the Firebase Array, handling owner room deletion, and severing Agora
  Future<bool> permanentlyLeaveChatroomDB(String chatroomId, String currentUserId) async {
    try {
      final chatroomRef = _firestore.collection('openChatrooms').doc(chatroomId);
      final chatroomDoc = await chatroomRef.get();

      if (!chatroomDoc.exists) {
        await leaveVoiceChat();
        return true;
      }

      final data = chatroomDoc.data()!;
      final participantCount = data['participantCount'] ?? 0;
      final creatorId = data['creatorId'];
      final participants = List<dynamic>.from(data['participants'] ?? []);

      // If the user was kicked (removed from participants by owner), they don't have
      // permission to write to this document anymore. We can just skip updating Firestore.
      if (!participants.contains(currentUserId)) {
        await _clearPresence();
        await leaveVoiceChat();
        return true;
      }

      if (participantCount <= 1 || creatorId == currentUserId) {
        // Cancel RTDB presence before deleting (owner / last person leaving)
        await _clearPresence();
        await chatroomRef.delete();
      } else {
        participants.remove(currentUserId);
        
        final updateData = <String, dynamic>{
          'participants': participants,
          'participantCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Cancel RTDB presence BEFORE updating Firestore so the Cloud Function
        // never sees an "offline" event after the count was already decremented.
        await _clearPresence();
        await chatroomRef.update(updateData);
      }

      await leaveVoiceChat();
      return true;
    } catch (e) {
      debugPrint('Leave DB Error: $e');
      return false;
    }
  }

  Future<void> muteRemoteUser(int remoteUid) async {
    if (_engine != null) {
      await _engine!.muteRemoteAudioStream(
        uid: remoteUid,
        mute: true,
      );
    }
  }

}
