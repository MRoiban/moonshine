#include "streaming/input/keyboardlistener.h"

#include <QByteArray>

namespace {
bool hasRequiredModifiers(char activeModifiers, char requiredModifiers)
{
    return (activeModifiers & requiredModifiers) == requiredModifiers;
}

void resolveShortcutKeyName(const QString& keyName, SDL_Keycode* keyCode, SDL_Scancode* scanCode)
{
    QByteArray keyNameUtf8 = keyName.trimmed().toUtf8();

    *keyCode = keyNameUtf8.isEmpty() ? SDLK_UNKNOWN : SDL_GetKeyFromName(keyNameUtf8.constData());
    *scanCode = keyNameUtf8.isEmpty() ? SDL_SCANCODE_UNKNOWN : SDL_GetScancodeFromName(keyNameUtf8.constData());

    if (*keyCode == SDLK_UNKNOWN && *scanCode != SDL_SCANCODE_UNKNOWN) {
        *keyCode = SDL_GetKeyFromScancode(*scanCode);
    }
    if (*scanCode == SDL_SCANCODE_UNKNOWN && *keyCode != SDLK_UNKNOWN) {
        *scanCode = SDL_GetScancodeFromKey(*keyCode);
    }
}
}

void SdlKeyboardListener::remapShortcut(Shortcut shortcut, SDL_Keycode keyCode, SDL_Scancode scanCode,
                                        char requiredModifiers, bool enabled)
{
    Binding binding;
    binding.shortcut = shortcut;
    binding.keyCode = keyCode;
    binding.scanCode = scanCode;
    binding.requiredModifiers = requiredModifiers;
    binding.enabled = enabled;

    for (Binding& existingBinding : m_Bindings) {
        if (existingBinding.shortcut == shortcut) {
            existingBinding = binding;
            return;
        }
    }

    m_Bindings.append(binding);
}

void SdlKeyboardListener::remapShortcutByName(Shortcut shortcut, const QString& keyName, char requiredModifiers,
                                              bool enabled, SDL_Keycode fallbackKeyCode,
                                              SDL_Scancode fallbackScanCode)
{
    SDL_Keycode keyCode;
    SDL_Scancode scanCode;
    resolveShortcutKeyName(keyName, &keyCode, &scanCode);

    if (keyCode == SDLK_UNKNOWN && scanCode == SDL_SCANCODE_UNKNOWN) {
        keyCode = fallbackKeyCode;
        scanCode = fallbackScanCode;
    }

    remapShortcut(shortcut, keyCode, scanCode, requiredModifiers, enabled);
}

SdlKeyboardListener::Shortcut SdlKeyboardListener::matchKeyPress(const SDL_KeyboardEvent* event,
                                                                 char activeModifiers) const
{
    if (event->state != SDL_PRESSED) {
        return ShortcutNone;
    }

    for (const Binding& binding : m_Bindings) {
        if (binding.enabled &&
            hasRequiredModifiers(activeModifiers, binding.requiredModifiers) &&
            binding.keyCode != SDLK_UNKNOWN &&
            event->keysym.sym == binding.keyCode) {
            return binding.shortcut;
        }
    }

    for (const Binding& binding : m_Bindings) {
        if (binding.enabled &&
            hasRequiredModifiers(activeModifiers, binding.requiredModifiers) &&
            binding.scanCode != SDL_SCANCODE_UNKNOWN &&
            event->keysym.scancode == binding.scanCode) {
            return binding.shortcut;
        }
    }

    return ShortcutNone;
}
