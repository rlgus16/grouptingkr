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
  LatLng _currentPosition = const LatLng(37.5665, 126.9780); // 기본값: 서울시청
  String _selectedAddress = '위치를 탐색 중입니다...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

    // 초기 위치의 주소 가져오기
    _getAddressFromLatLng(_currentPosition);
  }

  // 좌표를 주소로 변환 (Reverse Geocoding)
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'ko_KR',
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // 예: 서울특별시 강남구 역삼동
        String address = '${place.administrativeArea} ${place.locality} ${place.subLocality} ${place.thoroughfare}'.replaceAll('null', '').trim();

        // 너무 상세한 주소가 싫다면 아래처럼 간소화 가능
        if (address.isEmpty) {
          address = '${place.street}';
        }

        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = '주소를 찾을 수 없습니다.';
      });
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
              // 카메라가 멈췄을 때 중앙 좌표의 주소를 가져옴
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

          // 중앙 고정 핀 아이콘
          const Center(
            child: Icon(Icons.location_on, size: 40, color: AppTheme.primaryColor),
          ),

          // 하단 주소 표시 및 선택 버튼
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedAddress,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // 선택된 주소를 반환하며 화면 닫기
                        Navigator.pop(context, _selectedAddress);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('이 위치로 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height:50)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}