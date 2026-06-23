import 'package:flutter/material.dart';
import 'package:zmall/services/service.dart';

class ServiceLogsScreen extends StatefulWidget {
  static const String routeName = '/service-logs';

  @override
  _ServiceLogsScreenState createState() => _ServiceLogsScreenState();
}

class _ServiceLogsScreenState extends State<ServiceLogsScreen> {
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final raw = await Service.read('service_logs');
    setState(() {
      _logs = raw is List ? raw : (raw ?? []) as List<dynamic>;
    });
  }

  Future<void> _clearLogs() async {
    await Service.remove('service_logs');
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Logs'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Clear logs?'),
                  content: Text('Remove all saved service logs?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) await _clearLogs();
            },
          ),
        ],
      ),
      body: _logs.isEmpty
          ? Center(child: Text('No service logs'))
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, i) {
                  final entry = _logs[i] as Map<String, dynamic>;
                  return ListTile(
                    title: Text('${entry['endpoint'] ?? 'unknown'}'),
                    subtitle: Text(
                      '${entry['response_truncated'] ?? entry['error'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(entry['logged_at']?.toString() ?? ''),
                  );
                },
              ),
            ),
    );
  }
}
