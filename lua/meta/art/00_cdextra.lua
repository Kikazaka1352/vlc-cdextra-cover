--[[
  CD Extra Cover Art for VLC — version 1.0.0
  Track cover art for CD Extra (Enhanced CD) discs burned with Nero,
  taken from the JPEG pictures on the disc (PICTURES\NAME.NNJ).

  Copyright (c) 2026 Kikazaka1352
  SPDX-License-Identifier: MIT  (see LICENSE)

  ---

  CD Extra: обложки дорожек для VLC.

  Для аудио-CD формата CD Extra (записанного Nero) берёт обложку из части
  диска с данными: файлы PICTURES\ИМЯ.NNJ (JPEG), где NN — номер дорожки,
  00 — весь альбом. ИМЯ у картинок дорожек — код языка (RU, US, …).
  Для дорожки N: сначала ИМЯ.NNJ на предпочитаемом языке, потом на других,
  иначе обложка альбома ИМЯ.00J (JACKET* в приоритете).

  VLC вызывает этот скрипт сам в начале каждой дорожки.
]]

-- Предпочитаемый язык картинок. nil — по языку системы.
-- Примеры: "US"  или список по порядку: { "US", "GB", "RU" }.
-- Вместо правки скрипта можно создать файл cdextra.ini со строкой  lang=US
-- (Windows: %APPDATA%\vlc\cdextra.ini, Linux: ~/.config/vlc/cdextra.ini).
local PREFERRED_LANG = nil

local WIN = package.config:sub(1, 1) == "\\"
local SEP = WIN and "\\" or "/"

-- Язык системы -> префиксы файлов по порядку предпочтения
local LANGS = {
  -- код, название в Windows, префиксы
  { "ru", "russian",    { "RU" } },
  { "en", "english",    { "US", "EN", "GB", "UK" } },
  { "ja", "japanese",   { "JP", "JA" } },
  { "de", "german",     { "DE", "GE" } },
  { "fr", "french",     { "FR" } },
  { "it", "italian",    { "IT" } },
  { "es", "spanish",    { "ES", "SP" } },
  { "pt", "portuguese", { "PT", "BR" } },
  { "nl", "dutch",      { "NL" } },
  { "pl", "polish",     { "PL" } },
  { "uk", "ukrainian",  { "UA", "UK" } },
  { "be", "belarusian", { "BY", "BE" } },
  { "kk", "kazakh",     { "KZ", "KK" } },
  { "cs", "czech",      { "CZ", "CS" } },
  { "sv", "swedish",    { "SE", "SV" } },
  { "fi", "finnish",    { "FI" } },
  { "tr", "turkish",    { "TR" } },
  { "zh", "chinese",    { "CN", "ZH", "TW" } },
  { "ko", "korean",     { "KR", "KO" } },
}
-- Страна в имени локали Windows -> префикс, который ставится первым
local WIN_COUNTRIES = { ["united kingdom"] = "GB", ["united states"] = "US",
                        ["brazil"] = "BR", ["taiwan"] = "TW" }

-- Имена, которые проверяются напрямую, если VLC не дал прочитать папку
local PROBE_ALBUM = { "JACKET01", "JACKET02", "JACKET", "COVER", "FRONT", "ALBUM" }
local PROBE_TRACK = { "RU", "US", "EN", "GB", "JP", "JA", "DE", "FR", "IT", "ES",
                      "NL", "KO", "ZH", "TRACK" }

function descriptor()
  return { scope = "local" }
end

local function log(msg)
  vlc.msg.dbg("[cdextra] " .. msg)
end

local function join(a, b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a .. b end
  return a .. SEP .. b
end

local function to_uri(path)
  if vlc.strings and vlc.strings.make_uri then
    local ok, u = pcall(vlc.strings.make_uri, path)
    if ok and u then return u end
  end
  local p = path:gsub("\\", "/")
  p = p:gsub("[^%w%-%._~/:]", function(c) return string.format("%%%02X", c:byte()) end)
  if p:sub(1, 1) ~= "/" then p = "/" .. p end
  return "file://" .. p
end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

-- Есть ли папка. Проверка через io.open, а не средствами VLC, чтобы на
-- обычных аудио-CD в сообщениях не было ошибок. Открыть папку как файл
-- нельзя: Windows отвечает «отказано в доступе» (13), Linux — «это папка»
-- (21) или открывает её; отсутствующая папка — «не найдено» (2).
local function dir_exists(path)
  local f, _, code = io.open(path, "rb")
  if f then f:close(); return true end
  return code == 13 or code == 21
end

-- Корень части диска с данными: G:\ на Windows, точка монтирования на Linux
local function data_root(uri)
  local p = uri:gsub("^[Cc][Dd][Dd][Aa]:/*", "")
  local letter = p:match("^(%a):")
  if letter then return letter:upper() .. ":" .. SEP end
  local f = io.open("/proc/mounts", "r")
  if f then
    for line in f:lines() do
      local mnt, fs = line:match("^%S+%s+(%S+)%s+(%S+)")
      if fs == "iso9660" or fs == "udf" then
        f:close()
        return (mnt:gsub("\\(%d%d%d)", function(o) return string.char(tonumber(o, 8)) end))
      end
    end
    f:close()
  end
  return nil
end

-- Имена файлов в папке. vlc.stream по адресу папки отдаёт её содержимое
-- через readdir; vlc.directory_stream — запасной вариант (в VLC 3 без
-- модуля stream_directory он не работает).
local function list_dir(dir)
  local uri = to_uri(dir)
  for _, ctor in ipairs({ vlc.stream, vlc.directory_stream }) do
    local ok, s = pcall(ctor, uri)
    if ok and s then
      local okr, items = pcall(function() return s:readdir("", true) end)
      if okr and type(items) == "table" then
        local names = {}
        for _, it in ipairs(items) do
          local okn, n = pcall(function() return it:name() end)
          if okn and n and n ~= "" then names[#names + 1] = n end
        end
        return names
      end
    end
  end
  return nil
end

-- Без списка папки: проверить известные имена напрямую
local function probe(dir, track, codes)
  local names, seen = {}, {}
  local function try(base, nn)
    local name = string.format("%s.%02dJ", base, nn)
    if seen[name] then return end
    seen[name] = true
    if exists(join(dir, name)) then names[#names + 1] = name end
  end
  for _, b in ipairs(PROBE_ALBUM) do try(b, 0) end
  if track then
    for _, b in ipairs(codes) do try(b, track) end
    for _, b in ipairs(PROBE_TRACK) do try(b, track) end
  end
  return names
end

---------------------------------------------------------------------------
-- Язык

local function system_locale()
  for _, v in ipairs({ "LC_ALL", "LC_MESSAGES", "LANG", "LANGUAGE" }) do
    local s = os.getenv(v)
    if s and s ~= "" and s ~= "POSIX" and s ~= "C" and not s:match("^C%.") then
      return (s:match("^[^:]+"))
    end
  end
  -- Windows: имя локали системы, например "Russian_Russia.1251".
  -- Категория collate меняется на мгновение и сразу возвращается.
  local ok, old = pcall(os.setlocale, nil, "collate")
  local ok2, sys = pcall(os.setlocale, "", "collate")
  if ok and old then pcall(os.setlocale, old, "collate") end
  if ok2 and sys and sys ~= "C" then return sys end
  return nil
end

local function codes_for_locale(loc)
  if not loc then return {} end
  local l = loc:lower()
  local lang, country = l:match("^(%a%a)[_%-](%a%a)")          -- ru_RU, en-GB
  if not lang then lang = l:match("^(%a%a)$") or l:match("^(%a%a)[%.@]") end
  local wname, wcountry = l:match("^([%a ]+)_([%a ]+)")         -- English_United Kingdom
  for _, e in ipairs(LANGS) do
    if lang == e[1] or wname == e[2] then
      local first = country and country:upper() or WIN_COUNTRIES[wcountry or ""]
      local codes = {}
      for _, c in ipairs(e[3]) do
        if c == first then table.insert(codes, 1, c) else codes[#codes + 1] = c end
      end
      if first == "GB" then                     -- GB и UK — одна страна
        for i, c in ipairs(codes) do
          if c == "UK" then table.remove(codes, i); table.insert(codes, 2, "UK"); break end
        end
      end
      return codes
    end
  end
  return {}
end

local function config_lang()
  local dir
  if WIN then
    local ad = os.getenv("APPDATA")
    dir = ad and join(ad, "vlc")
  else
    local home = os.getenv("HOME")
    dir = home and (home .. "/.config/vlc")
  end
  local f = dir and io.open(join(dir, "cdextra.ini"), "r")
  if not f then return nil end
  local value
  for line in f:lines() do
    local v = line:match("^%s*lang%s*=%s*(.-)%s*$")
    if v and v ~= "" then value = v end
  end
  f:close()
  return value
end

local function split_codes(v)
  local codes = {}
  if type(v) == "table" then
    for _, c in ipairs(v) do codes[#codes + 1] = tostring(c):upper() end
  elseif type(v) == "string" then
    for c in v:gmatch("[%w]+") do codes[#codes + 1] = c:upper() end
  end
  return codes
end

-- Префиксы по порядку предпочтения и откуда они взяты
local function preferred_codes()
  local v = config_lang()
  if v then return split_codes(v), "cdextra.ini" end
  if PREFERRED_LANG then return split_codes(PREFERRED_LANG), "PREFERRED_LANG" end
  local loc = system_locale()
  return codes_for_locale(loc), "система: " .. tostring(loc)
end

-- Позиция префикса имени в списке языков (меньше — лучше)
local function lang_rank(base, codes)
  local b = base:upper()
  for i, c in ipairs(codes) do
    if b == c or b:sub(1, #c + 1):match("^" .. c .. "[^%a]") then return i end
  end
  return #codes + 1
end

---------------------------------------------------------------------------

-- Кандидаты по порядку: свои картинки дорожки (сначала на предпочитаемом
-- языке), затем обложки альбома (JACKET*, потом по языку)
local function candidates(names, track, codes)
  local own, album = {}, {}
  for _, n in ipairs(names) do
    local clean = n:gsub(";%d+$", "")
    local base, nn = clean:match("^(.-)%.(%d%d)[Jj]$")
    if base and base ~= "" then
      nn = tonumber(nn)
      local e = { name = clean, lang = lang_rank(base, codes),
                  jacket = base:upper():find("JACKET", 1, true) and 0 or 1 }
      if track and nn == track then own[#own + 1] = e
      elseif nn == 0 then album[#album + 1] = e end
    end
  end
  table.sort(own, function(a, b)
    if a.lang ~= b.lang then return a.lang < b.lang end
    return a.name < b.name
  end)
  table.sort(album, function(a, b)
    if a.jacket ~= b.jacket then return a.jacket < b.jacket end
    if a.lang ~= b.lang then return a.lang < b.lang end
    return a.name < b.name
  end)
  local list = {}
  for _, e in ipairs(own) do list[#list + 1] = e.name end
  for _, e in ipairs(album) do list[#list + 1] = e.name end
  return list
end

-- Кеш во временной папке: Windows сама чистит её при очистке диска,
-- а нужную картинку скрипт потом просто скопирует с диска заново
local function cache_dir()
  local cands = {}
  local function add(d)
    if d and d ~= "" and not d:find("[\128-\255]") then cands[#cands + 1] = d end
  end
  if WIN then
    add(os.getenv("TEMP"))
    add(os.getenv("TMP"))
    local ad = os.getenv("APPDATA")
    if ad then add(join(ad, "vlc")) end
  else
    local home = os.getenv("HOME")
    if home then add(home .. "/.cache/vlc") end
    add("/tmp")
  end
  for _, d in ipairs(cands) do
    local t = join(d, "cdextra.tmp")
    local f = io.open(t, "wb")
    if f then f:close(); os.remove(t); return d end
  end
  return nil
end

-- Путь в кеше для файла с диска. Берутся только имя и размер (эти данные
-- Windows держит в памяти), содержимое не читается — привод не трогается.
local function cache_target(cdir, path, name)
  local f = io.open(path, "rb")
  if not f then return nil, "не открывается" end
  local size = f:seek("end") or 0
  f:close()
  if size % 2336 == 0 then return nil, "файл в секторах Form 2, прочитать его так нельзя" end
  local h, s = 5381, name:upper() .. ":" .. size
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967291 end
  return join(cdir, string.format("cdextra-%08x.jpg", h))
end

-- Скопировать JPEG с диска в кеш
local function copy_file(path, out)
  local f = io.open(path, "rb")
  if not f then return false, "не открывается" end
  local data = f:read("*a") or ""
  f:close()
  if data:sub(1, 3) ~= "\255\216\255" then return false, "не JPEG" end
  local tmp = out .. ".tmp"
  local w = io.open(tmp, "wb")
  if not w then return false, "не удалось записать " .. tmp end
  w:write(data)
  w:close()
  os.remove(out)
  if not os.rename(tmp, out) then os.remove(tmp); return false, "не удалось записать " .. out end
  return true
end

-- Первый из кандидатов, который удалось взять (из кеша или скопировав)
local function take(cdir, dir, list, allow_copy)
  for _, name in ipairs(list) do
    local out, err = cache_target(cdir, join(dir, name), name)
    if out and exists(out) then return out, name, false end
    -- лучший подходящий файл ещё не скопирован: худший из кеша не берём
    if out and not allow_copy then return nil end
    if out and allow_copy then
      local ok, e = copy_file(join(dir, name), out)
      if ok then return out, name, true end
      err = e
    end
    if err and allow_copy then log(name .. ": " .. err) end
  end
  return nil
end

function fetch_art()
  local item = vlc.item
  if not item then return nil end
  local uri = item:uri()
  if not uri or not uri:lower():match("^cdda:") then return nil end

  local m = item:metas() or {}
  local track = tonumber(tostring(m.track_number or ""):match("%d+") or "")
  if not track then
    track = tonumber((item:name() or ""):match("(%d+)%s*$") or "")
  end

  local root = data_root(uri)
  if not root then log("не найдена часть диска с данными"); return nil end

  -- Это CD Extra? У него есть папки PICTURES и/или CDPLUS (Blue Book).
  -- У обычного аудио-CD их нет — тогда ничего не ищем.
  local dir
  for _, d in ipairs(WIN and { "PICTURES" } or { "PICTURES", "pictures" }) do
    if dir_exists(join(root, d)) then dir = join(root, d); break end
  end
  if not dir then
    if dir_exists(join(root, "CDPLUS")) or (not WIN and dir_exists(join(root, "cdplus"))) then
      log("CD Extra без папки PICTURES — картинок нет")
    else
      log("не CD Extra (нет папок CDPLUS и PICTURES)")
    end
    return nil
  end

  local cdir = cache_dir()
  if not cdir then log("нет папки для кеша"); return nil end

  local codes, from = preferred_codes()
  log("языки картинок: " .. (#codes > 0 and table.concat(codes, ", ") or "не определены")
      .. " (" .. from .. ")")

  local names = list_dir(dir) or probe(dir, track, codes)

  -- 1) Уже в кеше — диск не читаем
  local out, name = take(cdir, dir, candidates(names, track, codes), false)
  if out then
    log("дорожка " .. tostring(track) .. ": " .. name .. " (из кеша)")
    return to_uri(out)
  end

  -- 2) Нет в кеше: копируем один файл — для этой дорожки.
  --    (Копировать всё сразу нельзя: пока играет музыка, каждое чтение
  --    данных уводит привод с аудиодорожки, и звук прерывается.)
  out, name = take(cdir, dir, candidates(names, track, codes), true)
  if not out then
    log("дорожка " .. tostring(track) .. ": нет подходящей картинки *.J")
    return nil
  end
  log("дорожка " .. tostring(track) .. ": " .. name .. " (скопирована с диска)")
  return to_uri(out)
end
