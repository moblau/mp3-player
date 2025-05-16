// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  // Predefined list of music genres
  final List<String> _allGenres = [
    'Rock', 'Pop', 'Jazz', 'Classical',
    'Hip-Hop', 'Electronic', 'Country', 'Other'
  ];
  List<String> _favoriteGenres = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    final user = _auth.currentUser;
    if (user == null) {
      // No user signed in — stop spinner and exit
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _fire.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _usernameController.text   = data['username'] ?? '';
        _bioController.text        = data['bio']      ?? '';
        _favoriteGenres            = List<String>.from(data['favoriteGenres'] ?? []);
      }
    } catch (e) {
      // You might want to show an error here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      // Always hide spinner
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) return;

    await _fire.collection('users').doc(user.uid).set({
      'username': _usernameController.text.trim(),
      'bio':      _bioController.text.trim(),
      'favoriteGenres': _favoriteGenres,
    });

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully'))
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v == null || v.isEmpty ? 'Enter a username' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Favorite Genres', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _allGenres.map((genre) {
                  final selected = _favoriteGenres.contains(genre);
                  return FilterChip(
                    label: Text(genre),
                    selected: selected,
                    onSelected: (isSel) {
                      setState(() {
                        if (isSel) {
                          _favoriteGenres.add(genre);
                        } else {
                          _favoriteGenres.remove(genre);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
