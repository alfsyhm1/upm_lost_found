# upm_lost_found

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build & Setup Notes

If you plan to build this project locally (Android), please note:

- This project requires Java 17 for the Android Gradle Plugin. Install OpenJDK 17 (Homebrew on macOS):

	```bash
	brew install openjdk@17
	# then add to your ~/.zshrc (Apple Silicon):
	echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
	echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"' >> ~/.zshrc
	source ~/.zshrc
	java -version
	```

- I upgraded `flutter_image_compress` to `^2.4.0` to avoid an old plugin Gradle issue. If you see any local pub-cache edits under `~/.pub-cache`, you can safely remove them after running `flutter pub get`.

- If you encounter AAR metadata checks complaining about newer Java APIs, ensure core library desugaring is enabled in `android/app/build.gradle.kts`:

	```kotlin
	compileOptions {
			sourceCompatibility = JavaVersion.VERSION_11
			targetCompatibility = JavaVersion.VERSION_11
			isCoreLibraryDesugaringEnabled = true
	}

	dependencies {
			coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
	}
	```

If you'd like, I can help upgrade additional dependencies in small batches and verify the build after each change.
