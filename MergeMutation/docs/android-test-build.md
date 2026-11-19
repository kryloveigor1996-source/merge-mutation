# PR21 — первая Android debug APK

Успешный файл: `builds/android/merge-mutation-pr21.apk` относительно Git-корня. Полный путь: `C:/Users/User/OneDrive/Documents/ChatGPT/Games/MergeMutation/builds/android/merge-mutation-pr21.apk`.

- 37 058 028 байт (35,34 MiB), SHA-256 `56BA731F752F42B1FA2F2ABB307B90AC5BE1BD3526D62C12EAD60C155AC7E916`.
- Пакет `org.mergemutation.prototype.debug`, имя `Merge Mutation Test`.
- versionCode 21, versionName `2.0.0-pr21-test`.
- arm64-v8a, minSdk 24 (Android 7), targetSdk 36, горизонтальный экран.
- Подпись проверена apksigner: v2 и v3; zipalign 4 / 16 KiB прошёл.
- Встроены все 9 музыкальных ресурсов и обе конфигурации. Исходники генератора, тесты, docs и reference PNG исключены.
- Обычный Android debug режим не даёт игровых читов. Developer/legacy-пути закрыты проверкой платформы.

## Инструменты и воспроизведение

Использованы Godot 4.7.2.stable.steam.ed1daf0bf и соответствующие export templates 4.7.2.stable, установленные в portable editor_data Steam. SDK — `%LOCALAPPDATA%/Android/Sdk`, build-tools 36.0.0, JDK Eclipse Adoptium 17.0.20.1+1. JDK17 соответствует [инструкции Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

`export_presets.cfg` содержит только тестовые настройки. Путь SDK/JDK остаётся локальной настройкой редактора. Включён импорт ETC2/ASTC, иконка использует существующий PNG Слизика.

```powershell
$engine='C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
./MergeMutation/tools/run_godot.ps1 -GodotPath $engine -Mode export -DebugExport -ExportPreset 'Android Test' -OutputName 'merge-mutation-pr21-rebuilt.apk' -Label pr21-rebuild
$env:JAVA_HOME='C:/Program Files/Eclipse Adoptium/jdk-17.0.20.1+1'
./MergeMutation/tools/check_android_build.ps1 -ApkPath 'builds/android/merge-mutation-pr21-rebuilt.apk'
```

Команды выполняются из Git-корня. Wrapper не перезаписывает существующий APK. Новый filename обязателен для повторной сборки. Все логи идут в `logs/`, APK — в `builds/android/`; Git их игнорирует.

Устанавливаемый debug APK технически требует подписи: использован уже установленный стандартный локальный debug-keystore редактора. Production-ключи не использовались, новые ключи не создавались, ключи/пароли не включены в preset, Git, docs или APK. Это тестовая подпись, не подготовка публикации в Google Play. APK не является релизной сборкой.

## Установка на телефон

1. Убедиться, что телефон поддерживает arm64 и Android 7+. Скопировать указанный APK по USB или другим доверенным способом.
2. Открыть APK в файловом менеджере телефона и временно разрешить этому приложению установку из неизвестных источников. Подтвердить установку `Merge Mutation Test`.
3. Альтернатива: включить USB debugging, подтвердить компьютер на телефоне, выполнить `adb devices`, затем `adb install -r "C:/Users/User/OneDrive/Documents/ChatGPT/Games/MergeMutation/builds/android/merge-mutation-pr21.apk"`.
4. Запустить `Merge Mutation Test`. У тестового пакета отдельные данные; Windows-сохранение автоматически не переносится.
5. Пройти [форму плейтеста](core-gameplay-loop-playtest.md). Проверить landscape, вырез экрана, touch, системный Back, сворачивание/возврат, звук, победу, ремонт, повторный запуск.
6. При несовпадении старой тестовой подписи не удалять приложение с прогрессом автоматически. Сначала сохранить данные/обсудить перенос. `adb uninstall` удаляет локальные сохранения.

## Фактические пределы проверки

15 проверок пакета прошли: подпись, метаданные, ABI, debug-флаг, orientation, alignment, отсутствие исключённых файлов, 9 OGG и обязательные runtime-ресурсы. `adb devices -l` пуст; `emulator -list-avds` пуст. Запуск/касания/Back/сворачивание на Android **не проверены**. GPU и synthetic touch прогоны выполнялись на Windows.

Рост APK от музыки оценивается по фактическим 7 161 109 байтам исходных OGG (~6,83 MiB); отдельная сборка без музыки не создавалась, поэтому точную разницу APK не заявляем. Для принятия нужны прослушивание на динамике/наушниках и проверка памяти/нагрева на целевом телефоне.