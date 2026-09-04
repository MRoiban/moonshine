#include "streaming/input/macfnkeys.h"

#ifdef Q_OS_DARWIN

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hidsystem/IOHIDLib.h>
#include <IOKit/hidsystem/IOHIDParameter.h>
#include <IOKit/hidsystem/IOHIDShared.h>
#include <SDL_log.h>

namespace {
io_connect_t openHidParamConnection()
{
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                       IOServiceMatching(kIOHIDSystemClass));
    if (service == MACH_PORT_NULL) {
        return MACH_PORT_NULL;
    }

    io_connect_t connection = MACH_PORT_NULL;
    kern_return_t result = IOServiceOpen(service,
                                         mach_task_self(),
                                         kIOHIDParamConnectType,
                                         &connection);
    IOObjectRelease(service);

    if (result != KERN_SUCCESS) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to open IOHIDSystem parameter connection: 0x%x",
                    result);
        return MACH_PORT_NULL;
    }

    return connection;
}
}

MacFnKeyModeGuard::MacFnKeyModeGuard()
    : m_Active(false),
      m_HasSavedMode(false),
      m_SavedMode(false)
{
}

MacFnKeyModeGuard::~MacFnKeyModeGuard()
{
    restore();
}

void MacFnKeyModeGuard::setActive(bool active)
{
    if (active == m_Active) {
        return;
    }

    if (active) {
        if (!m_HasSavedMode && !readFKeyMode(&m_SavedMode)) {
            return;
        }

        m_HasSavedMode = true;
        if (!setFKeyMode(true)) {
            return;
        }

        m_Active = true;
    }
    else {
        restore();
    }
}

bool MacFnKeyModeGuard::readFKeyMode(bool* enabled)
{
    io_connect_t connection = openHidParamConnection();
    if (connection == MACH_PORT_NULL) {
        return false;
    }

    int mode = 0;
    IOByteCount actualSize = 0;
    kern_return_t result = IOHIDGetParameter(connection,
                                             CFSTR(kIOHIDFKeyModeKey),
                                             sizeof(mode),
                                             &mode,
                                             &actualSize);
    IOServiceClose(connection);

    if (result != KERN_SUCCESS || actualSize != sizeof(mode)) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to read macOS function key mode: 0x%x",
                    result);
        return false;
    }

    *enabled = mode != 0;
    return true;
}

bool MacFnKeyModeGuard::setFKeyMode(bool enabled)
{
    io_connect_t connection = openHidParamConnection();
    if (connection == MACH_PORT_NULL) {
        return false;
    }

    int mode = enabled ? 1 : 0;
    kern_return_t result = IOHIDSetParameter(connection,
                                             CFSTR(kIOHIDFKeyModeKey),
                                             &mode,
                                             sizeof(mode));
    IOServiceClose(connection);

    if (result != KERN_SUCCESS) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to set macOS function key mode: 0x%x",
                    result);
        return false;
    }

    return true;
}

void MacFnKeyModeGuard::restore()
{
    if (!m_Active) {
        return;
    }

    if (m_HasSavedMode) {
        setFKeyMode(m_SavedMode);
    }

    m_Active = false;
}

#endif
