import 'package:supabase_flutter/supabase_flutter.dart';

class TenantContext {
  TenantContext._();

  static String? _cachedTenantId;

  static void clearCache() {
    _cachedTenantId = null;
  }

  static Future<String?> tryGetTenantId() async {
    if (_cachedTenantId != null && _cachedTenantId!.isNotEmpty) {
      return _cachedTenantId;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final metadataTenant = _tenantFromMetadata(user);
    if (metadataTenant != null) {
      _cachedTenantId = metadataTenant;
      return metadataTenant;
    }

    final adminTenant = await _tenantFromAdminUser(client, user.id);
    if (adminTenant != null) {
      _cachedTenantId = adminTenant;
      return adminTenant;
    }

    final profileTenant = await _tenantFromUserProfile(client, user.id);
    if (profileTenant != null) {
      _cachedTenantId = profileTenant;
      return profileTenant;
    }

    final ownerTenant = await _tenantFromTenantOwner(client, user.id);
    if (ownerTenant != null) {
      _cachedTenantId = ownerTenant;
      return ownerTenant;
    }

    return null;
  }

  static Future<String> requireTenantId() async {
    final tenantId = await tryGetTenantId();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
        'No tenant mapping found for this account. Contact your administrator.',
      );
    }
    return tenantId;
  }

  static String? _tenantFromMetadata(User user) {
    final appMetadata = user.appMetadata;
    final userMetadata = user.userMetadata;

    final directApp = appMetadata['tenant_id'];
    if (directApp is String && directApp.trim().isNotEmpty) {
      return directApp.trim();
    }

    final camelApp = appMetadata['tenantId'];
    if (camelApp is String && camelApp.trim().isNotEmpty) {
      return camelApp.trim();
    }

    final directUser = userMetadata?['tenant_id'];
    if (directUser is String && directUser.trim().isNotEmpty) {
      return directUser.trim();
    }

    final camelUser = userMetadata?['tenantId'];
    if (camelUser is String && camelUser.trim().isNotEmpty) {
      return camelUser.trim();
    }

    return null;
  }

  static Future<String?> _tenantFromAdminUser(
    SupabaseClient client,
    String authUserId,
  ) async {
    try {
      final row = await client
          .from('admin_users')
          .select('tenant_id')
          .eq('auth_id', authUserId)
          .eq('is_active', true)
          .not('tenant_id', 'is', null)
          .maybeSingle();
      final tenantId = row?['tenant_id'] as String?;
      if (tenantId != null && tenantId.trim().isNotEmpty) {
        return tenantId.trim();
      }
    } catch (_) {
      // Ignore and continue to the next lookup strategy.
    }

    return null;
  }

  static Future<String?> _tenantFromUserProfile(
    SupabaseClient client,
    String authUserId,
  ) async {
    try {
      final row = await client
          .from('users')
          .select('tenant_id')
          .eq('auth_id', authUserId)
          .not('tenant_id', 'is', null)
          .maybeSingle();
      final tenantId = row?['tenant_id'] as String?;
      if (tenantId != null && tenantId.trim().isNotEmpty) {
        return tenantId.trim();
      }
    } catch (_) {
      // Ignore and continue to fallback lookup.
    }

    try {
      final row = await client
          .from('users')
          .select('tenant_id')
          .eq('id', authUserId)
          .not('tenant_id', 'is', null)
          .maybeSingle();
      final tenantId = row?['tenant_id'] as String?;
      if (tenantId != null && tenantId.trim().isNotEmpty) {
        return tenantId.trim();
      }
    } catch (_) {
      // Ignore and continue to fallback lookup.
    }

    return null;
  }

  static Future<String?> _tenantFromTenantOwner(
    SupabaseClient client,
    String authUserId,
  ) async {
    try {
      final row = await client
          .from('tenants')
          .select('id')
          .eq('owner_id', authUserId)
          .maybeSingle();
      final tenantId = row?['id'] as String?;
      if (tenantId != null && tenantId.trim().isNotEmpty) {
        return tenantId.trim();
      }
    } catch (_) {
      // No fallback left.
    }

    return null;
  }
}
