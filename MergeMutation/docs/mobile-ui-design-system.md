# Mobile UI Design System — реализованные компоненты

Утверждённая композиция A подключена через единственную фабрику `evolution_game.gd`. Модели/сохранения/экономика прежние. `mobile_lab.gd` собирает экраны, `mobile_layout.gd` рассчитывает геометрию, `mobile_ui.gd` создаёт Theme/Container/anchors.

## Координаты и размеры

Portrait: scale=usable_width/540; logical_height=usable_height/scale. Landscape: scale=usable_height/540; ширина динамическая. Safe area из физических координат переводится в canvas один раз. Нет общего вписывания540×960.

Touch минимум `max(84*font_scale,48*logical_width/usable_width_dp)` по обеим осям. При360dp и font100%84ед.=56dp; при меньшей доступной dp-ширине минимум автоматически увеличивается. Значение font_scale берётся из Android scaledDensity/density, тесты покрывают100–135%. Очень крупный accessibility-шрифт выше135% требует отдельной ручной приёмки.

Android: встроенный JavaClassWrapper обращается к Resources.getSystem().getDisplayMetrics(), density/scaledDensity через публичные `Class.getField`/`Field.getFloat`, без чтения instance-полей через Object.get. Проверены numeric/NaN/null и fallback при Java exception. Если bridge недоступен — явный DPI fallback; источник хранится в layout.density_source. [Android DisplayMetrics](https://developer.android.com/reference/android/util/DisplayMetrics#density), [Godot Java bridge](https://docs.godotengine.org/en/4.7/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html). Нативный путь не исполняется в Windows, проверить на устройстве.

## Компоненты

| Компонент | Реализация |
|---|---|
| Шапка/ресурсы/навигация | mobile_chrome: контейнеры, три основных маршрута; специальный экран заменяет общий HUD |
| Кнопка/карточка/текст | mobile_ui: общая тема, focus/pressed/disabled, перенос и min-size |
| Головоломки | mobile_puzzle_chrome: цели, подробности, действия, подтверждение restart, контекст без перекрытия поля |
| Модальные окна | непрозрачная подложка, scroll body, Back закрывает верхний слой |
| Обустройство | mobile_habitat: preview, реальные цены, явная покупка/отмена; низ portrait, правая панель landscape |
| Прокрутка | mobile_scroll: свайп отменяет кнопку, secondary/cancel не нажимают; нативный Range/LineEdit/OptionButton отдельно |
| Звук | mobile_slider: экранное касание/drag; release без press ничего не меняет |
| Подсказки | mobile_tutorial: прежняя очередь/сохранение, текст в зарезервированной области |

Фон#11191D, панели#1D292E, текст#EFF5EE, биология#A6D78B, порталы#B99ADD. Действия имеют прежние разные значки/стоимость, не один цвет. Новые художественные ресурсы/шрифты/музыка не добавлены. Расширение экрана не меняет игровую модель; resize/Back/pause завершают или отменяют жест и согласуют визуальные координаты.

[Android Field.getFloat](https://developer.android.com/reference/java/lang/reflect/Field#getFloat(java.lang.Object)) описывает получение значения публичного float-поля; этот путь использует только встроенный JNI и не требует Android-плагина. Модельный FakeBridge проверяет последовательность вызовов, не заменяет проверку реального JNI на устройстве.
