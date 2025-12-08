import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';

class LocationPickerView extends StatefulWidget {
  const LocationPickerView({super.key});

  @override
  State<LocationPickerView> createState() => _LocationPickerViewState();
}

class _LocationPickerViewState extends State<LocationPickerView> {
  GoogleMapController? _mapController;
  // 기본값: 서울시청
  LatLng _currentPosition = const LatLng(37.5665, 126.9780);
  String _selectedAddress = '위치를 탐색 중입니다...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  // 현재 위치 초기화
  Future<void> _initCurrentLocation() async {
    try {
      // 1. 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // 위치 서비스 꺼져있음 -> 기본 위치로 지도 표시
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // 권한 거부됨 -> 기본 위치로 지도 표시
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 권한 영구 거부됨 -> 기본 위치로 지도 표시
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // 초기 위치 주소 변환
      _getAddressFromLatLng(_currentPosition);

    } catch (e) {
      debugPrint("위치 오류: $e");
      // 에러 발생 시에도 로딩을 끝내고 지도를 보여줌 (기본 위치)
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 좌표 -> 주소 변환
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'ko_KR',
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // 주소 조합 (null 문자열 제거 및 공백 정리)
        String address = '${place.administrativeArea} ${place.locality} ${place.thoroughfare}'
            .replaceAll('null', '')
            .trim();

        if (address.isEmpty) {
          address = place.street ?? '주소 정보 없음';
        }

        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = '주소를 찾을 수 없습니다.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('활동지역 선택'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 로딩 상태가 아닐 때만 지도 표시
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 16,
              ),
              myLocationEnabled: true, // 내 위치 파란 점 표시
              myLocationButtonEnabled: true, // 내 위치로 이동 버튼
              zoomControlsEnabled: false, // 줌 버튼 숨김 (UI 깔끔하게)
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onCameraIdle: () async {
                if (_mapController != null) {
                  final bounds = await _mapController!.getVisibleRegion();
                  final center = LatLng(
                    (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                    (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
                  );
                  _getAddressFromLatLng(center);
                }
              },
            ),

          // 지도 중앙 고정 핀
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40), // 핀 끝이 중앙에 오도록 살짝 올림
              child: Icon(Icons.location_on, size: 50, color: AppTheme.primaryColor),
            ),
          ),

          // 하단 주소 표시 패널
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedAddress,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedAddress);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                            '이 위치로 설정',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                            )
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}