You are a senior Flutter/Dart engineer. Fix this project so it compiles successfully without removing or breaking any existing functionality.

The GitHub Actions workflow is working correctly. The failure is caused by Flutter compile errors. Your task is to fix every compile error until the project builds successfully with:

flutter pub get
flutter analyze
flutter build apk --split-per-abi

Requirements:
- Do NOT remove features to silence errors.
- Do NOT comment out code unless absolutely necessary.
- Preserve all existing functionality, UI, animations, networking, Quick Beam, LocalSend compatibility, and architecture.
- Fix imports, missing dependencies, Riverpod API usage, localization, null safety, generated files, and any API incompatibilities.
- Update pubspec.yaml only if required.
- Regenerate generated files if necessary.
- Fix the code properly instead of using temporary workarounds.

Current errors include:
- Type 'FavoriteEntry' not found.
- Type 'CrossFile' not found.
- The method 'watch' isn't defined for type 'Ref'.
- The getter 'clear' isn't defined in translations.
- Required named parameter 'background' must be provided.
- notificationStrings isn't defined.
- Object?.size errors.
- num cannot be returned where int is expected.
- Any additional compile errors that appear after these are fixed.

Do not stop after fixing the first errors. Continue fixing every compile error until the project builds successfully with zero compile errors.

At the end:
1. Explain the root cause of each error.
2. List every file modified.
3. Show the exact code changes.
4. Confirm that the project successfully passes:
   - flutter pub get
   - flutter analyze
   - flutter build apk --split-per-abi

The final result must be a fully working project that GitHub Actions can build into a release APK without any errors.
