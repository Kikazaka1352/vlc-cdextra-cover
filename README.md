# CD Extra Cover Art for VLC

*[Русский — ниже](#русский)*

A small Lua script for VLC that shows track cover art for **CD Extra
(Enhanced CD)** discs burned with **Nero**. The pictures are taken from the
data part of the disc, where Nero stores them as JPEG files:

```
PICTURES\NAME.NNJ
```

- `NN` is the track number, `00` means the whole album;
- for per-track pictures `NAME` is a language code: `RU.01J`, `US.01J`, …;
- for track N the script picks `*.NNJ` in the preferred language, then in
  any other language, and otherwise the album cover `*.00J`
  (names containing `JACKET` first).

VLC runs the script by itself at the start of every track. Ordinary audio
CDs (without `PICTURES` or `CDPLUS` folders) are skipped right away.

## Installation

Copy `lua/meta/art/00_cdextra.lua` to the `meta/art` folder of VLC's Lua
scripts (create the folders if they don't exist) and restart VLC:

| System  | Folder |
|---------|--------|
| Windows | `%APPDATA%\vlc\lua\meta\art\` or `C:\Program Files\VideoLAN\VLC\lua\meta\art\` |
| Linux   | `~/.local/share/vlc/lua/meta/art/` |

In **Tools → Preferences → Interface**, the **album art policy** must not be
"Manual download only".

## Language

By default the language comes from the system locale: Russian Windows →
`RU`; English (US) → `US`, `EN`, `GB`, `UK`; English (UK) → `GB`, `UK`, …
About twenty languages are mapped.

To choose yourself, create `cdextra.ini` with one line:

```
lang=US
```

Several languages in order of preference are allowed: `lang=US, GB, RU`.

- Windows: `%APPDATA%\vlc\cdextra.ini`
- Linux: `~/.config/vlc/cdextra.ini`

The same can be set in the script itself (`local PREFERRED_LANG = "US"`);
`cdextra.ini` takes precedence.

## Cache

Each picture is copied from the disc once, the first time its track is
played, into a cache folder: `%TEMP%\cdextra-*.jpg` on Windows,
`~/.cache/vlc/` on Linux. After that it is found by file name and size
without reading the disc. Windows cleans its temp folder from time to time;
the picture is then simply copied again.

## Known limitations

- **Only `*.J` (JPEG) pictures are supported.** The MPEG still pictures
  (`*.L`, `*.A`, `*.P`, Blue Book format) are stored in Mode 2 Form 2
  sectors, which the operating system returns truncated, so they are not
  used. A `*.J` file stored in Form 2 cannot be read either.
- **Short audio dropout** the first time a track's picture is read: the
  drive has to leave the audio track for a moment, and VLC's default disc
  buffer is only 0.3 s. Raising **Tools → Preferences → All → Input / Codecs
  → Disc caching (ms)** to 2000–3000 usually hides it (at the cost of a
  slower start of playback).
- **Disc location:** on Windows the drive letter is taken from the `cdda://`
  address; on Linux the first mounted `iso9660`/`udf` file system is used.
  macOS is not supported.

## Testing — honestly

- **Tested in real use** by the author: VLC 3.0 on Windows with one CD Extra
  disc burned with Nero — covers appear per track, language selection works.
- **Checked only in a simulated VLC environment** (not on real hardware):
  skipping ordinary audio CDs, the `cdextra.ini` override, other system
  languages, the Linux code path.
- **Not tested at all:** VLC 4, Linux and macOS on real hardware, discs
  made with software other than Nero.

Bug reports with the VLC log lines starting with `[cdextra]`
(**Tools → Messages**, verbosity "Debug") are welcome.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Kikazaka1352.

---

<a id="русский"></a>

# CD Extra: обложки дорожек для VLC

Небольшой Lua-скрипт для VLC: показывает обложки дорожек для дисков
**CD Extra (Enhanced CD)**, записанных в **Nero**. Картинки берутся из части
диска с данными, где Nero хранит их в виде JPEG:

```
PICTURES\ИМЯ.NNJ
```

- `NN` — номер дорожки, `00` — весь альбом;
- у картинок дорожек `ИМЯ` — код языка: `RU.01J`, `US.01J`, …;
- для дорожки N берётся `*.NNJ` на предпочитаемом языке, потом на любом
  другом, иначе обложка альбома `*.00J` (имена с `JACKET` в приоритете).

VLC запускает скрипт сам в начале каждой дорожки. Обычные аудио-CD (без папок
`PICTURES` и `CDPLUS`) скрипт сразу пропускает.

## Установка

Скопируйте `lua/meta/art/00_cdextra.lua` в папку `meta/art` Lua-скриптов VLC
(если папок нет — создайте) и перезапустите VLC:

| Система | Папка |
|---------|-------|
| Windows | `%APPDATA%\vlc\lua\meta\art\` или `C:\Program Files\VideoLAN\VLC\lua\meta\art\` |
| Linux   | `~/.local/share/vlc/lua/meta/art/` |

В **«Инструменты → Настройки → Интерфейс»** «Политика загрузки обложек»
должна быть не «Только вручную».

## Язык

По умолчанию язык берётся из системы: русская Windows → `RU`; английская
(США) → `US`, `EN`, `GB`, `UK`; британская → `GB`, `UK`, … Всего около
двадцати языков.

Чтобы выбрать самому, создайте файл `cdextra.ini` с одной строкой:

```
lang=US
```

Можно несколько по порядку: `lang=US, GB, RU`.

- Windows: `%APPDATA%\vlc\cdextra.ini`
- Linux: `~/.config/vlc/cdextra.ini`

То же можно задать в самом скрипте (`local PREFERRED_LANG = "US"`);
`cdextra.ini` главнее.

## Кеш

Каждая картинка копируется с диска один раз — при первом проигрывании её
дорожки — в папку кеша: `%TEMP%\cdextra-*.jpg` на Windows, `~/.cache/vlc/`
на Linux. Дальше она находится по имени и размеру файла, без чтения диска.
Windows время от времени чистит временную папку; тогда картинка просто
скопируется заново.

## Ограничения

- **Поддерживаются только картинки `*.J` (JPEG).** Кадры MPEG (`*.L`, `*.A`,
  `*.P`, формат Blue Book) лежат в секторах Mode 2 Form 2, которые система
  отдаёт обрезанными, поэтому не используются. Файл `*.J` в секторах Form 2
  тоже не прочитать.
- **Короткий обрыв звука** при первом чтении картинки дорожки: приводу
  приходится на мгновение уйти с аудиодорожки, а буфер VLC для дисков по
  умолчанию всего 0,3 с. Обычно помогает **«Инструменты → Настройки → Все →
  Ввод / кодеки → Кэширование дисков (мс)» = 2000–3000** (ценой более долгого
  начала воспроизведения).
- **Поиск диска:** на Windows буква привода берётся из адреса `cdda://`; на
  Linux — первая смонтированная файловая система `iso9660`/`udf`. macOS не
  поддерживается.

## Что проверено — честно

- **Проверено на практике** автором: VLC 3.0 на Windows, один диск CD Extra,
  записанный в Nero, — обложки появляются по дорожкам, выбор языка работает.
- **Проверено только в имитации окружения VLC** (не на реальном железе):
  пропуск обычных аудио-CD, настройка через `cdextra.ini`, другие языки
  системы, работа на Linux.
- **Не проверялось совсем:** VLC 4, Linux и macOS на реальном железе, диски,
  записанные не в Nero.

Сообщения об ошибках с приложенными строками лога `[cdextra]`
(**«Инструменты → Сообщения»**, уровень «Отладка») приветствуются.

## Лицензия

MIT — см. [LICENSE](LICENSE). Copyright (c) 2026 Kikazaka1352.
