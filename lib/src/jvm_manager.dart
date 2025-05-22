import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class JvmManager {
  final String home = '${Platform.environment['HOME']}/.jvm';
  final String versionsDir = '${Platform.environment['HOME']}/.jvm/versions';

  Future<void> listInstalledVersions() async {
    final dir = Directory(versionsDir);
    if (!dir.existsSync()) {
      print('No versions installed.');
      return;
    }

    final versions = dir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();

    if (versions.isEmpty) {
      print('No versions installed.');
    } else {
      print('Installed Java versions:');
      for (final v in versions) {
        print('- $v');
      }
    }
  }

  Future<void> downloadVersion(String version) async {
    final destDir = Directory(p.join(versionsDir, version));
    if (destDir.existsSync()) {
      print('Version $version already downloaded.');
      return;
    }

    print('Downloading Java $version...');
    final url = getAdoptiumUrl(version);
    print("url: $url");

    final cacheDir = Directory(p.join(home, 'cache'));
    cacheDir.createSync(recursive: true);

    final tmpZip = File(p.join(cacheDir.path, '$version.tar.gz'));

    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    print("Response: ${response.statusCode}");
    if (response.statusCode != 200) {
      print('Failed to download JDK. HTTP ${response.statusCode}');
      return;
    }

    final contentLength = response.contentLength ?? 0;
    final sink = tmpZip.openWrite();
    int downloaded = 0;
    int lastPercent = -1;

    await response.stream.listen(
      (chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          final percent = ((downloaded / contentLength) * 100).floor();
          if (percent != lastPercent) {
            stdout.write('\rDownloading: $percent%');
            lastPercent = percent;
          }
        }
      },
      onDone: () async {
        await sink.close();
        print('\rDownloading: 100% ✅');
        print('Extracting...');
        destDir.createSync(recursive: true);
        final result = await Process.run('tar', [
          '-xzf',
          tmpZip.path,
          '-C',
          destDir.path,
          '--strip-components=1',
        ]);

        if (result.exitCode == 0) {
          print('Java $version installed.');
        } else {
          print('Extraction failed: ${result.stderr}');
        }

        client.close();
      },
      onError: (e) {
        print('Download failed: $e');
        client.close();
      },
      cancelOnError: true,
    );
  }

  Future<void> useVersion(String version) async {
    final src = Directory(p.join(versionsDir, version));
    if (!src.existsSync()) {
      print('Version $version not found. Use `jvm download $version` first.');
      return;
    }

    // Create .jvm/java symlink
    final projectJvm = Directory(p.join(Directory.current.path, '.jvm'));
    final link = Link(p.join(projectJvm.path, 'java'));
    projectJvm.createSync(recursive: true);

    if (link.existsSync() || FileSystemEntity.isLinkSync(link.path)) {
      link.deleteSync();
    }

    link.createSync(src.path, recursive: true);
    print('Linked $version to .jvm/java');

    // Write full path to gradle.properties
    final gradleProps =
        File(p.join(Directory.current.path, 'android', 'gradle.properties'));
    gradleProps.createSync(recursive: true);

    final javaHomePath =
        p.normalize(p.join(projectJvm.path, 'java', 'Contents', 'Home'));

    List<String> lines = gradleProps.readAsLinesSync();
    lines
        .removeWhere((line) => line.trim().startsWith('org.gradle.java.home='));
    lines.add('org.gradle.java.home=$javaHomePath');

    gradleProps.writeAsStringSync(lines.join('\n'));
    print('Set org.gradle.java.home to $javaHomePath');

    // Write version to .jvmrc
    initProject();
    final rc = File(p.join(Directory.current.path, '.jvmrc'));
    rc.writeAsStringSync(version);
    print('Wrote $version to .jvmrc');
  }

  Future<void> reset() async {
    // Remove .jvmrc
    final rc = File(p.join(Directory.current.path, '.jvmrc'));
    if (rc.existsSync()) {
      rc.deleteSync();
      print('Removed .jvmrc');
    }

    // Remove .jvm/java symlink
    final link = Link(p.join(Directory.current.path, '.jvm', 'java'));
    if (link.existsSync() || FileSystemEntity.isLinkSync(link.path)) {
      link.deleteSync();
      print('Removed .jvm/java symlink');
    }

    // Remove org.gradle.java.home from gradle.properties
    final gradleProps =
        File(p.join(Directory.current.path, 'android', 'gradle.properties'));
    if (gradleProps.existsSync()) {
      List<String> lines = gradleProps.readAsLinesSync();
      final filtered = lines
          .where((line) => !line.trim().startsWith('org.gradle.java.home='))
          .toList();
      gradleProps.writeAsStringSync(filtered.join('\n'));
      print('Removed org.gradle.java.home from gradle.properties');
    }
  }

  Future<void> initProject() async {
    final rc = File(p.join(Directory.current.path, '.jvmrc'));
    if (!rc.existsSync()) {
      rc.writeAsStringSync('');
      print('Initialized .jvmrc');
    }
  }

  String getAdoptiumUrl(String version) {
    // if (!version.contains('+')) {
    //   throw ArgumentError('Version must include build number, e.g. 17.0.8+7');
    // }

    final os = _mapOs(Platform.operatingSystem);
    final arch = _mapArch(Platform.version);

    return 'https://api.adoptium.net/v3/binary/version/jdk-$version/$os/$arch/jdk/hotspot/normal/eclipse';
  }

  String _mapOs(String dartOs) {
    switch (dartOs) {
      case 'macos':
        return 'mac';
      case 'linux':
        return 'linux';
      case 'windows':
        return 'windows';
      default:
        throw UnsupportedError('Unsupported operating system: $dartOs');
    }
  }

  String _mapArch(String dartVersion) {
    final archMatch = RegExp(r'on ".+_(\w+)"').firstMatch(dartVersion);
    final arch = archMatch?.group(1);

    if (arch == 'x64') return 'x64';
    if (arch == 'arm64' || arch == 'aarch64') return 'aarch64';

    throw UnsupportedError(
      'Unknown architecture in Dart version: $dartVersion',
    );
  }

  Future<void> fetchJavaVersion(String majorVersion) async {
    print(' Fetching Java $majorVersion versions...');

    final uri = Uri.parse(
      'https://api.adoptium.net/v3/assets/feature_releases/$majorVersion/ga?image_type=jdk',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      print(' Failed to fetch versions. HTTP ${response.statusCode}');
      return;
    }

    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty) {
      print(' No versions found for Java $majorVersion.');
      return;
    }

    final versions = <String>{};

    for (final release in data) {
      final releaseName = release['release_name'] as String?;
      if (releaseName != null && releaseName.startsWith('jdk-')) {
        final version = releaseName.substring(4);
        versions.add(version);
      }
    }

    if (versions.isEmpty) {
      print('No valid version info found.');
      return;
    }

    final sortedVersions = versions.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    print('\n Available Java $majorVersion versions:');
    for (var i = 0; i < sortedVersions.length; i++) {
      print(' [${i + 1}] ${sortedVersions[i]}');
    }

    stdout.write('\n👉 Choose a version by number: ');
    final selection = int.tryParse(stdin.readLineSync() ?? '');
    if (selection == null ||
        selection < 1 ||
        selection > sortedVersions.length) {
      print('Invalid selection.');
      return;
    }

    final selectedVersion = sortedVersions[selection - 1];
    downloadVersion(selectedVersion);
  }
}
