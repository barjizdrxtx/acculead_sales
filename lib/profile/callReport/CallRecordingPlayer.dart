import 'dart:io';
import 'dart:convert';
import 'package:acculead_sales/utls/url.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class CallRecordingPlayer extends StatefulWidget {
  const CallRecordingPlayer({Key? key}) : super(key: key);

  @override
  _CallRecordingPlayerState createState() => _CallRecordingPlayerState();
}

class _CallRecordingPlayerState extends State<CallRecordingPlayer> {
  final AudioPlayer _player = AudioPlayer();

  List<Map<String, dynamic>> _recordings = [];
  Set<String> _uploadedTitles = {};
  List<Map<String, String>> _leads = [];

  String? _playingPath;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player
      ..playerStateStream.listen((s) => setState(() => _isPlaying = s.playing))
      ..durationStream.listen((d) {
        if (d != null) setState(() => _duration = d);
      })
      ..positionStream.listen((p) => setState(() => _position = p));
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchLeads();
    await _fetchUploadedList();
    await _checkPermissionsAndLoad();
  }

  Future<void> _fetchLeads() async {
    try {
      final resp = await http.get(Uri.parse('${ApiConstants.baseUrl}/lead'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _leads = (data['result'] as List).map((e) {
          final m = e as Map<String, dynamic>;
          return {
            'phone': (m['phoneNumber'] as String).replaceAll(RegExp(r'\D'), ''),
            'name': (m['fullName'] ?? '') as String,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching leads: $e');
    }
  }

  Future<void> _fetchUploadedList() async {
    try {
      final resp = await http.get(Uri.parse('${ApiConstants.baseUrl}/audio'));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        _uploadedTitles = list
            .map((e) => (e as Map<String, dynamic>)['title'] as String)
            .toSet();
      }
    } catch (e) {
      debugPrint('Error fetching uploaded audio list: $e');
    }
  }

  Future<void> _checkPermissionsAndLoad() async {
    if (Platform.isAndroid) {
      final s = await Permission.storage.request();
      final m = await Permission.manageExternalStorage.request();
      if (!s.isGranted && !m.isGranted) {
        await openAppSettings();
        setState(() => _loading = false);
        return;
      }
    }
    await _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    final dirs = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Recordings',
    ];
    final exts = ['.mp3', '.m4a', '.wav', '.aac', '.ogg'];
    final files = <FileSystemEntity>[];
    for (final dp in dirs) {
      final dir = Directory(dp);
      if (await dir.exists()) {
        files.addAll(
          dir.listSync().where(
            (f) =>
                f is File && exts.any((e) => f.path.toLowerCase().endsWith(e)),
          ),
        );
      }
    }

    final pattern = RegExp(r'^(?:91)?(\d{10}(?:_\d+)+)$');
    final matches = <Map<String, dynamic>>[];

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';

    for (final f in files) {
      final name = p.basenameWithoutExtension(f.path);
      final match = pattern.firstMatch(name);
      if (match != null) {
        final fullPhoneAndIds = match.group(1)!;
        final phonePart = fullPhoneAndIds.split('_').first;
        final lead = _leads.firstWhere(
          (l) => l['phone']!.endsWith(phonePart),
          orElse: () => {},
        );
        if (lead.isNotEmpty) {
          final already = _uploadedTitles.contains(name);
          matches.add({
            'file': f,
            'leadName': lead['name']!,
            'leadPhone': lead['phone']!,
            'title': name,
            'uploaded': already,
            'userId': userId,
          });
        }
      }
    }

    setState(() {
      _recordings = matches;
      _loading = false;
    });

    for (final rec in matches) {
      if (!(rec['uploaded'] as bool)) {
        await _uploadFile(rec);
      }
    }
  }

  Future<void> _uploadFile(Map<String, dynamic> rec) async {
    final f = rec['file'] as File;
    final title = rec['title'] as String;
    final userId = rec['userId'] as String;

    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiConstants.baseUrl}/audio/upload'),
            )
            ..files.add(await http.MultipartFile.fromPath('file', f.path))
            ..fields['title'] = title
            ..fields['description'] = 'Auto-uploaded recording'
            ..fields['userId'] = userId;

      final rsp = await req.send();
      if (rsp.statusCode == 201) {
        setState(() {
          rec['uploaded'] = true;
          _uploadedTitles.add(title);
        });
      } else {
        debugPrint('Upload failed with ${rsp.statusCode}');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
  }

  Future<void> _playPause(String path) async {
    if (_playingPath == path && _isPlaying) {
      await _player.pause();
    } else {
      await _player.stop();
      await _player.setFilePath(path);
      await _player.play();
      setState(() => _playingPath = path);
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _playingPath = null;
      _position = Duration.zero;
    });
  }

  String _format(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Recording Player'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
          ? const Center(child: Text('No matching recordings found'))
          : ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (_, i) {
                final rec = _recordings[i];
                final f = rec['file'] as File;
                final path = f.path;
                final isCurr = path == _playingPath;
                final uploaded = rec['uploaded'] as bool;

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.audiotrack,
                      size: 32,
                      color: Colors.green,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec['leadName'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          rec['leadPhone'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          uploaded ? Icons.check_circle : Icons.cloud_upload,
                          color: uploaded ? Colors.green : Colors.blue,
                        ),
                        if (isCurr) ...[
                          Slider(
                            min: 0,
                            max: _duration.inMilliseconds.toDouble(),
                            value: _position.inMilliseconds
                                .clamp(0, _duration.inMilliseconds)
                                .toDouble(),
                            onChanged: (v) =>
                                _player.seek(Duration(milliseconds: v.toInt())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_format(_position)),
                              Text(_format(_duration)),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isCurr
                                ? (_isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle)
                                : Icons.play_circle,
                            color: Colors.blue,
                            size: 40,
                          ),
                          onPressed: () => _playPause(path),
                        ),
                        if (isCurr)
                          IconButton(
                            icon: const Icon(
                              Icons.stop_circle,
                              color: Colors.red,
                            ),
                            onPressed: _stop,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
