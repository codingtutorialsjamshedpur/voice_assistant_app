import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ruflo_service.dart';

class FamilyMember {
  final String id;
  final String deviceId;
  final String role;
  final int trustLevel;

  const FamilyMember({
    required this.id,
    required this.deviceId,
    required this.role,
    required this.trustLevel,
  });
}

class FederationService extends GetxService with WidgetsBindingObserver {
  final _ruflo = RuFloService();
  String _familyId = '';
  String _currentMemberId = '';

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _familyId.isNotEmpty) {
      unawaited(_ruflo.callTool('federation_sync', {
        'familyId': _familyId,
        'memberId': _currentMemberId,
      }));
    }
  }

  Future<void> initializeFederation(List<FamilyMember> members) async {
    await _ruflo.callTool('federation_init', {
      'name': 'family_$_familyId',
      'members': members.map((m) => {
        'id': m.id,
        'deviceId': m.deviceId,
        'role': m.role,
        'trustLevel': m.trustLevel,
      }).toList(),
    });
  }

  Future<void> syncToFamily(String key, Map<String, dynamic> data, {
    String privacy = 'family',
  }) async {
    if (privacy == 'private') return;
    unawaited(_ruflo.callTool('federation_broadcast', {
      'familyId': _familyId,
      'key': key,
      'data': data,
      'memberId': _currentMemberId,
    }));
  }

  Future<List<Map<String, dynamic>>> getFamilyContext(
    String query,
    String requestorId,
  ) async {
    final results = await _ruflo.memorySearch(
      namespace: 'family_shared_$_familyId',
      query: query,
      topK: 5,
    );
    return results;
  }

  void setFamilyContext(String familyId, String memberId) {
    _familyId = familyId;
    _currentMemberId = memberId;
  }

  Map<String, dynamic> resolveConflict(
    String key,
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localTime = local['updated_at'] as String? ?? '';
    final remoteTime = remote['updated_at'] as String? ?? '';
    return localTime.compareTo(remoteTime) >= 0 ? local : remote;
  }
}
