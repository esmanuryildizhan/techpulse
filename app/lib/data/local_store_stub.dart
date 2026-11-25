import 'local_store.dart';

/// dart:io olmayan platformlarda (web) bellek deposu kullanılır.
Future<LocalStore> openPlatformStore() async => MemoryStore();
