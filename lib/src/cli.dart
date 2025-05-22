import 'package:args/args.dart';
import 'package:jvm/src/jvm_manager.dart';

void run(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('list')
    ..addCommand('download')
    ..addCommand('use')
    ..addCommand('fetch');

  final results = parser.parse(args);
  final jvm = JvmManager();

  switch (results.command?.name) {
    case 'list':
      await jvm.listInstalledVersions();
      break;
    case 'download':
      final version = results.command?.rest.first;
      if (version != null) await jvm.downloadVersion(version);
      break;
    case 'use':
      final version = results.command?.rest.first;
      if (version != null) await jvm.useVersion(version);
      break;
    case 'fetch':
      final version = results.command?.rest.first;
      if (version != null) await jvm.fetchJavaVersion(version);
      break;

    default:
      printUsage();
  }
}

void printUsage() {
  print('''
JVM CLI – Java Version Manager for Dart/Flutter Projects

Usage:
  jvm <command> [arguments]

Available commands:
  list                List installed Java versions
  download <version>  Download and install a specific Java version
  use <version>       Set the Java version for the current project
  reset               Remove Java configuration for this project
  fetch <version>     Select and download a Java version from list

Examples:
  jvm list
  jvm download 17.0.8+7
  jvm use 17.0.8+7
  jvm reset
  jvm fetch 17

🔧 All project configuration is stored locally and automatically integrated with Gradle.
''');
}
