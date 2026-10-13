#pragma once

#include <QSettings>
#include <QtDebug>

namespace SettingsMigration {

// Separate the copy operation from store selection so it can be tested without
// touching native user preferences. The source is never written to.
inline bool copyIfEmpty(QSettings& destination, const QSettings& source)
{
    if (!destination.allKeys().isEmpty()) {
        qInfo() << "Moonshine settings already exist; skipping Moonlight migration";
        return false;
    }

    const QStringList keys = source.allKeys();
    if (source.status() != QSettings::NoError) {
        qWarning() << "Could not read Moonlight settings; migration deferred";
        return false;
    }

    for (const QString& key : keys) {
        destination.setValue(key, source.value(key));
    }
    destination.setValue(QStringLiteral("migratedFromMoonlight"), true);
    destination.sync();
    if (destination.status() != QSettings::NoError) {
        // The destination was empty on entry. Remove an incomplete migration
        // so a later launch can retry instead of treating it as user settings.
        destination.clear();
        destination.sync();
        qWarning() << "Could not save Moonlight settings migration";
        return false;
    }

    qInfo() << "Moonlight settings migration completed:" << keys.size()
            << "keys copied (including credentials and hosts); source unchanged";
    return true;
}

inline void migrateFromMoonlight()
{
    QSettings destination;
    destination.setFallbacksEnabled(false);

    // macOS prefers the organization domain even in portable INI mode.
    // Native macOS QSettings reverses this domain to select the exact legacy
    // CFPreferences domain: com.moonlight-stream.Moonlight.
#ifdef Q_OS_DARWIN
    const QString oldOrganization = QStringLiteral("moonlight-stream.com");
#else
    const QString oldOrganization = QStringLiteral("Moonlight Game Streaming Project");
#endif
    QSettings source(QSettings::defaultFormat(), QSettings::UserScope,
                     oldOrganization, QStringLiteral("Moonlight"));
    source.setFallbacksEnabled(false);
    copyIfEmpty(destination, source);
}

} // namespace SettingsMigration
