# neofetch for Windows

Красивый вывод информации о системе в стиле Linux **neofetch**.  
Работает в **PowerShell**, **Windows Terminal** и обычном **cmd**.

![preview](https://raw.githubusercontent.com/dylanaraps/neofetch/master/images/neofetch.png)

## Возможности

- ASCII-логотип Windows (в стиле настоящего neofetch)
- Реальные данные системы:
  - OS + build
  - Host / User
  - Kernel
  - Uptime
  - Packages (примерно)
  - Shell
  - Resolution
  - DE / WM
  - Terminal
  - CPU (название + ядра)
  - GPU
  - Memory
  - Disk (системный)
  - Battery (если есть)
- Цветные блоки внизу
- Работает без установки (просто запустить) или как команда `neofetch`

## Быстрый старт (без установки)

```powershell
# разрешить выполнение скриптов (один раз)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# запустить
.\neofetch.ps1
```

Или просто двойной клик по `neofetch.cmd`.

## Установка (чтобы работало из любого места)

Открой PowerShell **в папке с файлами** и выполни:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\install.ps1
```

После этого в **новом** терминале будет доступна команда:

```powershell
neofetch
```

Работает и в PowerShell, и в обычном cmd.

## Параметры

```
neofetch          # полный вывод
neofetch -NoArt   # только информация, без логотипа
neofetch -Help    # справка
```

## Требования

- Windows 10 / 11
- PowerShell 5.1 (встроен в Windows) или PowerShell 7+

Рекомендуется **Windows Terminal** — там цвета выглядят лучше всего.

## Удаление

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\neofetch"
# и убери путь из PATH пользователя при желании
```

---

Сделано для удовольствия. Наслаждайся.
