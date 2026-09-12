class ArchitectureScaffold {
  final String diagram;
  final List<EdgeCase> edgeCases;
  final List<String> patterns;

  ArchitectureScaffold({required this.diagram, required this.edgeCases, required this.patterns});

  factory ArchitectureScaffold.generate(String prompt) {
    final lower = prompt.toLowerCase();
    final components = <String>[];
    final edges = <String>[];
    final edgeCases = <EdgeCase>[];
    final patterns = <String>[];

    if (lower.contains('ecommerce') || lower.contains('e-commerce') || lower.contains('shop')) {
      components.addAll(['Client', 'CDN', 'API Gateway', 'Product Service', 'Cart Service', 'Order Service', 'Payment Service', 'Notification Service', 'Database', 'Cache']);
      edges.addAll([
        'Client -> CDN',
        'Client -> API Gateway',
        'API Gateway -> Product Service',
        'API Gateway -> Cart Service',
        'API Gateway -> Order Service',
        'API Gateway -> Payment Service',
        'Product Service -> Database',
        'Cart Service -> Cache',
        'Order Service -> Database',
        'Payment Service -> Payment Gateway',
        'Order Service -> Notification Service',
      ]);
      edgeCases.addAll([
        EdgeCase('Payment timeout', 'What happens if payment processing hangs?', 'warning'),
        EdgeCase('Concurrent cart updates', 'Race condition when multiple clients update cart simultaneously', 'warning'),
        EdgeCase('Inventory mismatch', 'Overselling if stock check and reserve are not atomic', 'critical'),
        EdgeCase('Cart abandonment', 'Stale cart data accumulating in cache', 'info'),
      ]);
      patterns.addAll(['Circuit Breaker', 'Idempotency Key', 'Saga Pattern', 'Cache-Aside']);
    } else if (lower.contains('social') || lower.contains('feed') || lower.contains('chat')) {
      components.addAll(['Client', 'API Gateway', 'User Service', 'Post Service', 'Feed Service', 'Notification Service', 'Chat Service', 'Database', 'Cache', 'Message Queue']);
      edges.addAll([
        'Client -> API Gateway',
        'API Gateway -> User Service',
        'API Gateway -> Post Service',
        'API Gateway -> Feed Service',
        'API Gateway -> Notification Service',
        'API Gateway -> Chat Service',
        'Feed Service -> Message Queue',
        'Chat Service -> Message Queue',
        'Notification Service -> Message Queue',
        'Post Service -> Cache',
        'User Service -> Database',
      ]);
      edgeCases.addAll([
        EdgeCase('Feed consistency', 'Eventually consistent feeds showing stale posts', 'warning'),
        EdgeCase('Message ordering', 'Messages arriving out of order in real-time chat', 'critical'),
        EdgeCase('Notification storm', 'User gets flooded with notifications', 'warning'),
        EdgeCase('Hot posts', 'Viral content causing cache stampede', 'info'),
      ]);
      patterns.addAll(['Event Sourcing', 'CQRS', 'Fan-out on Write', 'Rate Limiting']);
    } else if (lower.contains('iot') || lower.contains('device') || lower.contains('telemetry')) {
      components.addAll(['Devices', 'MQTT Broker', 'Ingestion Service', 'Stream Processor', 'Alert Service', 'Dashboard', 'Time-Series DB', 'Object Storage']);
      edges.addAll([
        'Devices -> MQTT Broker',
        'MQTT Broker -> Ingestion Service',
        'Ingestion Service -> Stream Processor',
        'Stream Processor -> Time-Series DB',
        'Stream Processor -> Alert Service',
        'Stream Processor -> Object Storage',
        'Dashboard -> Time-Series DB',
        'Alert Service -> Notification Service',
      ]);
      edgeCases.addAll([
        EdgeCase('Device disconnection', 'Handling intermittent connectivity and buffering', 'critical'),
        EdgeCase('Data burst', 'Massive telemetry upload overwhelming ingestion', 'warning'),
        EdgeCase('Alert fatigue', 'Too many alerts causing operators to ignore them', 'warning'),
        EdgeCase('Time synchronization', 'Clock skew between devices affecting analytics', 'info'),
      ]);
      patterns.addAll(['MQTT QoS Levels', 'Stream Buffering', 'Downsampling', 'Edge Computing']);
    } else if (lower.contains('saas') || lower.contains('multi-tenant') || lower.contains('subscription')) {
      components.addAll(['Client', 'API Gateway', 'Auth Service', 'Tenant Service', 'Billing Service', 'Usage Service', 'Database', 'Cache', 'Payment Gateway']);
      edges.addAll([
        'Client -> API Gateway',
        'API Gateway -> Auth Service',
        'API Gateway -> Tenant Service',
        'API Gateway -> Billing Service',
        'Billing Service -> Payment Gateway',
        'Auth Service -> Database',
        'Tenant Service -> Cache',
        'Usage Service -> Database',
      ]);
      edgeCases.addAll([
        EdgeCase('Tenant isolation breach', 'One tenant accessing another\'s data', 'critical'),
        EdgeCase('Billing race condition', 'Subscription status and access not in sync', 'critical'),
        EdgeCase('Usage spike', 'Single tenant consuming disproportionate resources', 'warning'),
        EdgeCase('Data migration', 'Schema changes across all tenants', 'info'),
      ]);
      patterns.addAll(['Row-Level Security', 'Schema per Tenant', 'Usage Throttling', 'Graceful Degradation']);
    } else {
      // Generic
      components.addAll(['Client', 'API Gateway', 'Service A', 'Service B', 'Database', 'Cache', 'Message Queue']);
      edges.addAll([
        'Client -> API Gateway',
        'API Gateway -> Service A',
        'API Gateway -> Service B',
        'Service A -> Database',
        'Service B -> Database',
        'Service A -> Cache',
        'Service A -> Message Queue',
        'Service B -> Message Queue',
      ]);
      edgeCases.addAll([
        EdgeCase('Single point of failure', 'API Gateway is a bottleneck', 'warning'),
        EdgeCase('Database contention', 'Multiple services writing to same tables', 'warning'),
        EdgeCase('Message loss', 'Queue overflow or consumer failure', 'critical'),
      ]);
      patterns.addAll(['Circuit Breaker', 'Retry with Backoff', 'Health Checks', 'Observability']);
    }

    final diagram = _buildDiagram(components, edges);
    return ArchitectureScaffold(diagram: diagram, edgeCases: edgeCases, patterns: patterns);
  }

  static String _buildDiagram(List<String> components, List<String> edges) {
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────┐');
    buffer.writeln('│  ARCHITECTURE SCAFFOLD                  │');
    buffer.writeln('├─────────────────────────────────────────┤');
    buffer.writeln('│                                         │');

    final maxLen = components.map((c) => c.length).fold(0, (a, b) => a > b ? a : b);
    final cols = 3;
    final rows = (components.length / cols).ceil();

    for (var r = 0; r < rows; r++) {
      final rowComponents = <String>[];
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        if (idx < components.length) {
          final comp = components[idx];
          final padded = comp.padRight(maxLen);
          rowComponents.add(padded);
        }
      }
      final line = rowComponents.map((c) => '  ${c.substring(0, maxLen)}').join('  │  ');
      buffer.writeln('│  $line  │');
      if (r < rows - 1) buffer.writeln('│                                         │');
    }

    buffer.writeln('│                                         │');
    buffer.writeln('│  EDGE CASES:                            │');
    buffer.writeln('│  ⚠ See detailed list in side panel     │');
    buffer.writeln('│                                         │');
    buffer.writeln('└─────────────────────────────────────────┘');

    return buffer.toString();
  }
}

class EdgeCase {
  final String title;
  final String description;
  final String severity;

  EdgeCase(this.title, this.description, this.severity);
}
