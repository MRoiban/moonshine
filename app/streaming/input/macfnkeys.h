#pragma once

#include <QtGlobal>

#ifdef Q_OS_DARWIN

class MacFnKeyModeGuard
{
public:
    MacFnKeyModeGuard();
    ~MacFnKeyModeGuard();

    void setActive(bool active);

private:
    bool setFKeyMode(bool enabled);
    bool readFKeyMode(bool* enabled);
    void restore();

    bool m_Active;
    bool m_HasSavedMode;
    bool m_SavedMode;
};

#endif
