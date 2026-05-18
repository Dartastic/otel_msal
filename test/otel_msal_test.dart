// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_msal/otel_msal.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(serviceName: 'otel_msal-test');
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('acquireTokenSilent records tenant + cache source + silent', () async {
    await tracedMsal<String>(
      operation: 'acquireTokenSilent',
      invoke: () async => const MsalCallResult(
        value: 'ok',
        result: MsalResult(
          tenantId: 'common',
          clientId: 'app_1',
          tokenSource: 'cache',
          silent: true,
          scopesGranted: ['User.Read', 'openid'],
          brokerUsed: false,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('msal acquireTokenSilent')!);
    expect(a['msal.token.source'], 'cache');
    expect(a['msal.silent'], true);
  });

  test('interaction_required does NOT set span error', () async {
    await tracedMsal<String>(
      operation: 'acquireTokenSilent',
      invoke: () async => const MsalCallResult(
        value: 'ok',
        result: MsalResult(errorCode: 'interaction_required'),
      ),
    );
    expect(
      spans.findSpanByName('msal acquireTokenSilent')!.status,
      isNot(SpanStatusCode.Error),
    );
  });

  test('consent_required sets span error', () async {
    await tracedMsal<String>(
      operation: 'acquireToken',
      invoke: () async => const MsalCallResult(
        value: 'ok',
        result: MsalResult(errorCode: 'consent_required'),
      ),
    );
    expect(
      spans.findSpanByName('msal acquireToken')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutMsalInstrumentationAsync(() async {
      await tracedMsal<String>(
        operation: 'signOut',
        invoke: () async => const MsalCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('msal '), isEmpty);
  });
}
