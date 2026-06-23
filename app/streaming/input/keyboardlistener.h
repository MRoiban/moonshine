#pragma once

#include "SDL_compat.h"

#include <QString>
#include <QVector>

class SdlKeyboardListener
{
public:
    enum Shortcut {
        ShortcutNone,
        ShortcutQuitActiveStream,
        ShortcutUngrabInput,
        ShortcutToggleFullScreen,
        ShortcutToggleStatsOverlay,
        ShortcutToggleMouseMode,
        ShortcutToggleCursorHide,
        ShortcutToggleMinimize,
        ShortcutPasteText,
        ShortcutTogglePointerRegionLock,
        ShortcutQuitAndExitHostApp,
        ShortcutToggleKeyboardGrab,
    };

    void remapShortcut(Shortcut shortcut, SDL_Keycode keyCode, SDL_Scancode scanCode,
                       char requiredModifiers, bool enabled = true);
    void remapShortcutByName(Shortcut shortcut, const QString& keyName, char requiredModifiers,
                             bool enabled, SDL_Keycode fallbackKeyCode, SDL_Scancode fallbackScanCode);

    Shortcut matchKeyPress(const SDL_KeyboardEvent* event, char activeModifiers) const;

private:
    struct Binding {
        Shortcut shortcut;
        SDL_Keycode keyCode;
        SDL_Scancode scanCode;
        char requiredModifiers;
        bool enabled;
    };

    QVector<Binding> m_Bindings;
};
