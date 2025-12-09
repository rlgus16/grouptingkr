import 'package:flutter/foundation.dart';

/// 그룹팅 성능 모니터링 유틸리티
/// 실시간 채팅 성능 및 UI 응답성 측정
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // 성능 측정 데이터
  final Map<String, List<int>> _messageSendTimes = {};
  final Map<String, List<int>> _messageReceiveTimes = {};
  final Map<String, int> _uiUpdateCounts = {};
  final Map<String, DateTime> _lastUpdateTimes = {};
  
  // 통계
  int _totalMessagesSent = 0;
  int _totalMessagesReceived = 0;
  double _averageSendTime = 0;
  double _averageReceiveTime = 0;

  /// 메시지 전송 시간 측정 시작
  Stopwatch startMessageSend(String messageId) {
    final stopwatch = Stopwatch()..start();
    debugPrint('📤 메시지 전송 시작: $messageId');
    return stopwatch;
  }

  /// 메시지 전송 완료 시간 기록
  void recordMessageSent(String messageId, Stopwatch stopwatch) {
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    
    _messageSendTimes.putIfAbsent(messageId, () => []).add(elapsed);
    _totalMessagesSent++;
    
    // 평균 계산
    final allSendTimes = _messageSendTimes.values.expand((times) => times);
    _averageSendTime = allSendTimes.isEmpty 
        ? 0 
        : allSendTimes.reduce((a, b) => a + b) / allSendTimes.length;
    
    debugPrint('📤 메시지 전송 완료: $messageId (${elapsed}ms)');
    if (elapsed > 1000) {
      debugPrint('⚠️ 느린 메시지 전송 감지: ${elapsed}ms');
    }
  }

  /// 메시지 수신 시간 측정
  void recordMessageReceived(String messageId, DateTime sentTime) {
    final now = DateTime.now();
    final elapsed = now.difference(sentTime).inMilliseconds;
    
    _messageReceiveTimes.putIfAbsent(messageId, () => []).add(elapsed);
    _totalMessagesReceived++;
    
    // 평균 계산
    final allReceiveTimes = _messageReceiveTimes.values.expand((times) => times);
    _averageReceiveTime = allReceiveTimes.isEmpty 
        ? 0 
        : allReceiveTimes.reduce((a, b) => a + b) / allReceiveTimes.length;
    
    debugPrint('📥 메시지 수신: $messageId (${elapsed}ms 지연)');
    if (elapsed > 2000) {
      debugPrint('⚠️ 느린 메시지 수신 감지: ${elapsed}ms');
    }
  }

  /// UI 업데이트 빈도 측정
  void recordUIUpdate(String componentName) {
    final now = DateTime.now();
    final lastUpdate = _lastUpdateTimes[componentName];
    
    _uiUpdateCounts[componentName] = (_uiUpdateCounts[componentName] ?? 0) + 1;
    
    if (lastUpdate != null) {
      final timeSinceLastUpdate = now.difference(lastUpdate).inMilliseconds;
      if (timeSinceLastUpdate < 50) {
        debugPrint('⚠️ 너무 빈번한 UI 업데이트: $componentName (${timeSinceLastUpdate}ms)');
      }
    }
    
    _lastUpdateTimes[componentName] = now;
  }

  /// 채팅방 성능 통계 출력
  void printChatPerformanceStats(String chatRoomId) {
    debugPrint('');
    debugPrint('📊 채팅방 성능 통계 ($chatRoomId)');
    debugPrint('═══════════════════════════════════');
    debugPrint('📤 전송된 메시지: $_totalMessagesSent개');
    debugPrint('📥 수신된 메시지: $_totalMessagesReceived개');
    debugPrint('⏱️ 평균 전송 시간: ${_averageSendTime.toStringAsFixed(1)}ms');
    debugPrint('⏱️ 평균 수신 지연: ${_averageReceiveTime.toStringAsFixed(1)}ms');
    debugPrint('');
    
    // UI 업데이트 통계
    debugPrint('🖥️ UI 업데이트 통계:');
    _uiUpdateCounts.forEach((component, count) {
      debugPrint('  - $component: ${count}회');
    });
    debugPrint('');
  }

  /// 성능 경고 확인
  List<String> getPerformanceWarnings() {
    final warnings = <String>[];
    
    if (_averageSendTime > 1000) {
      warnings.add('메시지 전송이 느림: ${_averageSendTime.toStringAsFixed(1)}ms');
    }
    
    if (_averageReceiveTime > 2000) {
      warnings.add('메시지 수신이 느림: ${_averageReceiveTime.toStringAsFixed(1)}ms');
    }
    
    _uiUpdateCounts.forEach((component, count) {
      if (count > 100) {
        warnings.add('UI 업데이트가 과다함: $component ($count회)');
      }
    });
    
    return warnings;
  }

  /// 성능 데이터 초기화
  void reset() {
    _messageSendTimes.clear();
    _messageReceiveTimes.clear();
    _uiUpdateCounts.clear();
    _lastUpdateTimes.clear();
    _totalMessagesSent = 0;
    _totalMessagesReceived = 0;
    _averageSendTime = 0;
    _averageReceiveTime = 0;
    debugPrint('🔄 성능 모니터 초기화 완료');
  }

  /// 메모리 사용량 체크 (개발 모드에서만)
  void checkMemoryUsage() {
    if (kDebugMode) {
      final cacheSize = _messageSendTimes.length + _messageReceiveTimes.length;
      if (cacheSize > 1000) {
        debugPrint('⚠️ 성능 모니터 캐시 크기 경고: $cacheSize개');
        // 오래된 데이터 정리
        _cleanupOldData();
      }
    }
  }

  /// 오래된 성능 데이터 정리
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    
    _lastUpdateTimes.removeWhere((key, time) => 
        time.isBefore(cutoff));
    
    // 최근 100개 메시지 데이터만 유지
    if (_messageSendTimes.length > 100) {
      final recentKeys = _messageSendTimes.keys.take(100).toList();
      _messageSendTimes.removeWhere((key, value) => 
          !recentKeys.contains(key));
    }
    
    if (_messageReceiveTimes.length > 100) {
      final recentKeys = _messageReceiveTimes.keys.take(100).toList();
      _messageReceiveTimes.removeWhere((key, value) => 
          !recentKeys.contains(key));
    }
    
    debugPrint('🧹 성능 모니터 캐시 정리 완료');
  }
}
