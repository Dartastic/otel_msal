// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_msal/otel_msal.dart';

/// Traces MSAL calls with OpenTelemetry.
///
/// `otel_msal` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each MSAL call in
/// [tracedMsal]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'msal-example');

  // Wraps an MSAL call in a CLIENT span.
  final msalId = await tracedMsal<String>(
    operation: 'create',
    invoke: () async {
      // Make the MSAL call here, then report what it returned.
      const id = 'msal_8f3a2c';
      return const MsalCallResult(
          value: id,
          result: MsalResult(
              tenantId: 'common',
              clientId: 'client_8f3a2c',
              authority: 'example',
              accountId: '<oid>.<tid>',
              username: 'example',
              cloudInstance: 'AzurePublic',
              scopesRequested: ['example'],
              scopesGranted: ['example'],
              tokenSource: 'cache',
              accessTokenLength: 128,
              idTokenLength: 128,
              expiresOnUnixSec: 1,
              silent: true,
              brokerUsed: true,
              errorCode: 'interaction_required',
              subError: 'example',
              correlationId: 'correlation_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedMsal create returned $msalId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutMsalInstrumentationAsync.
  await runWithoutMsalInstrumentationAsync(
    () => tracedMsal<String>(
      operation: 'create',
      invoke: () async {
        const id = 'msal_8f3a2c';
        return const MsalCallResult(
            value: id,
            result: MsalResult(
                tenantId: 'common',
                clientId: 'client_8f3a2c',
                authority: 'example',
                accountId: '<oid>.<tid>',
                username: 'example',
                cloudInstance: 'AzurePublic',
                scopesRequested: ['example'],
                scopesGranted: ['example'],
                tokenSource: 'cache',
                accessTokenLength: 128,
                idTokenLength: 128,
                expiresOnUnixSec: 1,
                silent: true,
                brokerUsed: true,
                errorCode: 'interaction_required',
                subError: 'example',
                correlationId: 'correlation_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
