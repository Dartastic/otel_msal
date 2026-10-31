// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_msal_suppression.dart';

const _tracerName = 'dartastic_otel_libs_msal';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class MsalResult {
  /// Creates a result.
  const MsalResult({
    this.tenantId,
    this.clientId,
    this.authority,
    this.accountId,
    this.username,
    this.cloudInstance,
    this.scopesRequested,
    this.scopesGranted,
    this.tokenSource,
    this.accessTokenLength,
    this.idTokenLength,
    this.expiresOnUnixSec,
    this.silent,
    this.brokerUsed,
    this.errorCode,
    this.subError,
    this.correlationId,
    this.statusCode,
  });

  /// Azure AD tenant id (or `common`, `organizations`, `consumers`).
  final String? tenantId;

  final String? clientId;

  /// Full authority URL.
  final String? authority;

  /// AAD account home id (`<oid>.<tid>`).
  final String? accountId;
  final String? username;

  /// `AzurePublic`, `AzureChina`, `AzureGermany`, `AzureUsGovernment`.
  final String? cloudInstance;

  final List<String>? scopesRequested;
  final List<String>? scopesGranted;

  /// `cache`, `identity_provider`, `broker`.
  final String? tokenSource;

  final int? accessTokenLength;
  final int? idTokenLength;
  final int? expiresOnUnixSec;

  /// `acquireTokenSilent` (no UI).
  final bool? silent;

  /// Microsoft Authenticator broker performed the token call.
  final bool? brokerUsed;

  /// MSAL error code (e.g. `interaction_required`, `no_account_in_cache`,
  /// `invalid_grant`, `consent_required`, `mfa_required`, `device_not_compliant`).
  final String? errorCode;
  final String? subError;
  final String? correlationId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class MsalCallResult<T> {
  /// Creates a call result.
  const MsalCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final MsalResult? result;
}

/// Wraps an MSAL call in a CLIENT span. [operation] is one of
/// `acquireToken`, `acquireTokenSilent`, `acquireTokenWithDeviceCode`,
/// `acquireTokenOnBehalfOf`, `acquireTokenByUsernamePassword`,
/// `acquireTokenByAuthorizationCode`, `signOut`, `removeAccount`,
/// `getAccounts`, `getAccount`, `getAuthority`.
Future<T> tracedMsal<T>({
  required String operation,
  required Future<MsalCallResult<T>> Function() invoke,
}) async {
  if (msalInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'msal',
    'rpc.method': operation,
    'msal.operation': operation,
  };

  final span = _tracer().startSpan(
    'msal $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final res = r.result!;
      final extras = <Attribute<Object>>[];
      if (res.tenantId != null) {
        extras.add(OTelAPI.attributeString('msal.tenant.id', res.tenantId!));
      }
      if (res.clientId != null) {
        extras.add(OTelAPI.attributeString('msal.client.id', res.clientId!));
      }
      if (res.authority != null) {
        extras.add(OTelAPI.attributeString('msal.authority', res.authority!));
      }
      if (res.accountId != null) {
        extras.add(OTelAPI.attributeString('msal.account.id', res.accountId!));
      }
      if (res.username != null) {
        extras.add(
            OTelAPI.attributeString('msal.account.username', res.username!));
      }
      if (res.cloudInstance != null) {
        extras.add(OTelAPI.attributeString(
          'msal.cloud.instance',
          res.cloudInstance!,
        ));
      }
      if (res.scopesRequested != null) {
        extras.add(OTelAPI.attributeStringList(
          'msal.scopes.requested',
          res.scopesRequested!,
        ));
      }
      if (res.scopesGranted != null) {
        extras.add(OTelAPI.attributeStringList(
          'msal.scopes.granted',
          res.scopesGranted!,
        ));
      }
      if (res.tokenSource != null) {
        extras.add(
            OTelAPI.attributeString('msal.token.source', res.tokenSource!));
      }
      if (res.accessTokenLength != null) {
        extras.add(OTelAPI.attributeInt(
          'msal.access_token.length',
          res.accessTokenLength!,
        ));
      }
      if (res.idTokenLength != null) {
        extras.add(OTelAPI.attributeInt(
          'msal.id_token.length',
          res.idTokenLength!,
        ));
      }
      if (res.expiresOnUnixSec != null) {
        extras.add(OTelAPI.attributeInt(
          'msal.expires_on_unix_sec',
          res.expiresOnUnixSec!,
        ));
      }
      if (res.silent != null) {
        extras.add(OTelAPI.attributeBool('msal.silent', res.silent!));
      }
      if (res.brokerUsed != null) {
        extras.add(OTelAPI.attributeBool('msal.broker.used', res.brokerUsed!));
      }
      if (res.errorCode != null) {
        extras.add(OTelAPI.attributeString('msal.error.code', res.errorCode!));
        if (res.errorCode != 'interaction_required' &&
            res.errorCode != 'no_account_in_cache') {
          span.setStatus(SpanStatusCode.Error, 'MSAL ${res.errorCode}');
        }
      }
      if (res.subError != null) {
        extras.add(OTelAPI.attributeString('msal.error.sub', res.subError!));
      }
      if (res.correlationId != null) {
        extras.add(OTelAPI.attributeString(
          'msal.correlation.id',
          res.correlationId!,
        ));
      }
      if (res.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          res.statusCode!,
        ));
        if (res.statusCode! >= 400) {
          span.setStatus(SpanStatusCode.Error, 'MSAL HTTP ${res.statusCode}');
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
