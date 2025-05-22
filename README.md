# jvm

A simple per-project Java version manager for Dart and Flutter projects — inspired by tools like FVM.

This CLI tool lets you install and configure specific Java versions per project. It automatically downloads JDKs.

---

## Features

- Install and manage Java versions.
- Per-project Java version configuration using `.jvmrc` and `.jvm/java`
- Automatic Gradle integration (`org.gradle.java.home`)
- Interactive version selection via `jvm fetch`
- Works seamlessly with FVM and Flutter projects

---

## Installation

To install globally:

```bash
dart pub global activate jvm
```
Then run using:

```bash
jvm <command>
```
```bash
Available commands

Command	Description
list	            List installed Java versions
download <version>	Download and install a specific Java version
use <version>	    Configure the current project to use that version
reset	            Remove local Java configuration
fetch <major>	    Interactively select and install a version by major

jvm list
jvm download 17.0.8+7
jvm use 17.0.8+7
jvm reset
jvm fetch 17
```
## FAQ
Q: Does this conflict with FVM?

A: No. jvm is designed to work alongside FVM. It configures Java per-project the same way FVM configures Flutter, without interfering with global tools.

Q: Does it modify global environment variables?

A: No. All configuration is scoped to the project directory. It modifies only .jvm, .jvmrc, and gradle.properties.

Q: Where are Java versions stored?

A: Under ~/.jvm/versions/<version>
