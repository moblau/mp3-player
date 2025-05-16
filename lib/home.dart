// lib/home.dart
import 'dart:io'           show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart'  show kIsWeb;
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

import 'profile.dart';  // ensure this import


/// A song can either be a local file (path/bytes) or a remote URL from Storage
class Song {
  final String name;
  final String? path;       // on mobile/desktop
  final Uint8List? bytes;   // on web
  final String? url;        // download URL from Firebase Storage

  Song({
    required this.name,
    this.path,
    this.bytes,
    this.url,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer     _player  = AudioPlayer();
  final List<Song>      _songs   = [];
  int?                 _playingIndex;
  double _speed = 1.0;

  final FirebaseAuth    _auth    = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _fire   = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadSongsFromStorage();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// 1) Fetch previously‐uploaded songs from Firestore
  Future<void> _loadSongsFromStorage() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefix = 'user_songs/${user.uid}';

    // listAll returns all files under that folder
    final result = await _storage.ref(prefix).listAll();

    // for each StorageReference, fetch its download URL
    final loaded = <Song>[];
    for (final ref in result.items) {
      final url = await ref.getDownloadURL();
      loaded.add(Song(name: ref.name, url: url));
    }

    setState(() {
      _songs.clear();
      _songs.addAll(loaded);
    });
  }

  /// Let the user pick a new local song
  Future<void> _pickSong() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.audio, withData: kIsWeb, allowMultiple: false);
    if (result == null) return;

    final file = result.files.single;
    setState(() {
      _songs.add(Song(
        name:  file.name,
        path:  kIsWeb ? null : file.path,
        bytes: kIsWeb ? file.bytes : null,
      ));
    });
  }

  /// Play either a local file or a remote URL
  Future<void> _playSong(int index) async {
    final song = _songs[index];
    try {
      if (song.url != null) {
        await _player.setUrl(song.url!);
      } else if (!kIsWeb && song.path != null) {
        await _player.setFilePath(song.path!);
      } else {
        // web‐bytes or missing data: skipping
        return;
      }
      await _player.setSpeed(_speed);
      await _player.play();
      setState(() => _playingIndex = index);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Play error: $e')),
      );
    }
  }


  /// Upload a local song to Firebase Storage + record in Firestore
  Future<void> _uploadSong(int index) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      return;
    }

    final song = _songs[index];
    final ref  = _storage.ref('user_songs/${user.uid}/${song.name}');
    UploadTask task;

    try {
      if (kIsWeb) {
        task = ref.putData(song.bytes!,
            SettableMetadata(contentType: 'audio/mpeg'));
      } else {
        task = ref.putFile(File(song.path!),
            SettableMetadata(contentType: 'audio/mpeg'));
      }

      final snap = await task;
      final url  = await snap.ref.getDownloadURL();

      // record metadata
      await _fire
          .collection('users')
          .doc(user.uid)
          .collection('songs')
          .add({
        'name':       song.name,
        'url':        url,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      // also update our local list entry so it knows its URL now
      setState(() {
        _songs[index] = Song(name: song.name, url: url);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Widget _buildSongTile(int i) {
    final song      = _songs[i];
    final isLocal   = song.url == null; // not yet uploaded
    final isPlaying = i == _playingIndex && _player.playing;

    return ListTile(
      title: Text(song.name),
      leading: IconButton(
        icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
        onPressed: () => isPlaying
            ? _player.pause()
            : _playSong(i),
      ),
      trailing: isLocal
      // only show upload icon for local songs
          ? IconButton(
        icon: const Icon(Icons.cloud_upload),
        onPressed: () => _uploadSong(i),
      )
          : null, // already on cloud
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My MP3 Player')),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // Pick a new local file
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.library_music),
              label: const Text('Select Song'),
              onPressed: _pickSong,
            ),
          ),

          const SizedBox(height: 16),

          // Show both loaded & newly picked songs
          Expanded(
            child: _songs.isEmpty
                ? const Center(child: Text('No songs selected'))
                : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (_, i) => _buildSongTile(i),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${_speed.toStringAsFixed(2)}×',
              value: _speed,
              onChanged: (val) {
                setState(() => _speed = val);
                _player.setSpeed(val);
              },
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            child: const Text(
              'Profile',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}