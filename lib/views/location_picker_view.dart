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
        localeIdentifier: 'ko_KR', // 한국어 설정 확인
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // 한국 주소 체계에 맞는 순서로 요소 배열 (시/도 -> 시/군/구 -> 읍/면/동 -> 상세)
        // subLocality(구)가 포함되어야 정확한 주소가 나옵니다.
        List<String?> addressParts = [
          place.administrativeArea, // 예: 서울특별시, 경기도
          place.locality,           // 예: 성남시 (광역시의 경우 null일 수 있음)
          place.subLocality,        // 예: 분당구 (현재 코드에서 빠져있음)
        ];

        // 1. null이나 빈 문자열 제거
        // 2. 중복 제거 (예: '서울특별시'가 administrativeArea와 locality에 모두 잡히는 경우 방지)
        // 3. 공백으로 연결
        String address = addressParts
            .where((part) => part != null && part.trim().isNotEmpty) // 유효한 값만 필터링
            .toSet() // 중복 제거 (순서 보장됨)
            .join(' '); // 공백으로 연결

        // 만약 조합된 주소가 비어있다면 street(전체 주소) 사용
        if (address.isEmpty) {
          address = place.street ?? '주소 정보 없음';
        }

        setState(() {
          _selectedAddress = address;
          _currentPosition = position;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint("주소 변환 오류: $e");
        setState(() {
          _selectedAddress = '주소를 찾을 수 없습니다.';
          _currentPosition = position;
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
              child: Icon(Icons.location_on, size: 50, color: AppTheme.errorColor),
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
                          Navigator.pop(context, {
                            'address': _selectedAddress,
                            'latitude': _currentPosition.latitude,
                            'longitude': _currentPosition.longitude,
                          });
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