// SPDX-License-Identifier: MIT
// The bridge between the interface and the camera.
//
// Every setting lives in one map, `values`, keyed by name ("hdr", "zoom",
// "zoneYawMin", ...). QML reads `cam.values.hdr` and writes with
// `cam.set("hdr", true)`. Changes show immediately, are sent to the camera on
// the worker thread, and are then confirmed or corrected by the status the
// camera pushes back. App preferences in the same map are saved to disk.
#pragma once

#include "camera.hpp"
#include "worker.hpp"

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QSettings>
#include <QTimer>
#include <QVariant>

#include <functional>
#include <memory>

class Controller : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool usbAvailable READ usbAvailable NOTIFY deviceChanged)
    Q_PROPERTY(bool simulated READ simulated CONSTANT)
    Q_PROPERTY(QString model READ model NOTIFY deviceChanged)
    Q_PROPERTY(QString serial READ serial NOTIFY deviceChanged)
    Q_PROPERTY(QString firmware READ firmware NOTIFY deviceChanged)
    Q_PROPERTY(QVariantMap values READ values NOTIFY valuesChanged)
    Q_PROPERTY(QVariantMap ranges READ ranges NOTIFY rangesChanged)
    Q_PROPERTY(QVariantList presets READ presets NOTIFY presetsChanged)
    Q_PROPERTY(int maxPresets READ maxPresets CONSTANT)
    // Where the camera points, as seen in the preview: up and right positive.
    Q_PROPERTY(double pan READ pan NOTIFY positionChanged)
    Q_PROPERTY(double tilt READ tilt NOTIFY positionChanged)
    // The same in the SDK's frame (for the tracking-area editor).
    Q_PROPERTY(double rawYaw READ rawYaw NOTIFY positionChanged)
    Q_PROPERTY(double rawPitch READ rawPitch NOTIFY positionChanged)
    Q_PROPERTY(bool trackingPaused READ trackingPaused NOTIFY trackingPausedChanged)
    Q_PROPERTY(QString activeProfile READ activeProfile NOTIFY activeProfileChanged)
    Q_PROPERTY(bool livePosition READ livePosition WRITE setLivePosition NOTIFY livePositionChanged)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QStringList shutterLabels READ shutterLabels CONSTANT)

public:
    explicit Controller(bool simulated, QObject *parent = nullptr);
    ~Controller() override;

    void start();

    bool connected() const { return m_connected; }
    bool usbAvailable() const { return m_usbAvailable; }
    bool simulated() const { return m_simulated; }
    QString model() const { return m_model; }
    QString serial() const { return m_serial; }
    QString firmware() const { return m_firmware; }
    QVariantMap values() const { return m_values; }
    QVariantMap ranges() const { return m_ranges; }
    QVariantList presets() const { return m_presets; }
    int maxPresets() const { return 3; }
    double pan() const;
    double tilt() const;
    double rawYaw() const { return m_yaw; }
    double rawPitch() const { return m_pitch; }
    bool trackingPaused() const { return m_trackingPaused; }
    QString activeProfile() const { return m_activeProfile; }
    bool livePosition() const { return m_livePosition; }
    void setLivePosition(bool on);
    QStringList profiles() const;
    QStringList shutterLabels() const;

    // Change a setting.
    Q_INVOKABLE void set(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant get(const QString &key) const { return m_values.value(key); }

    // Gimbal, in screen directions: -1..1 with up and right positive, scaled
    // by gimbalSpeed.
    Q_INVOKABLE void move(double tilt, double pan);
    // Move briefly in one direction (for the direction check).
    Q_INVOKABLE void nudge(double tilt, double pan);
    Q_INVOKABLE void stopMove();
    Q_INVOKABLE void recenter();
    Q_INVOKABLE void aimAt(double x, double y);            // point in the preview, 0..1
    Q_INVOKABLE void aimAbsolute(double pan, double tilt); // degrees, screen frame
    Q_INVOKABLE void zoomBy(int delta);

    // Tracking on/off. Turning it on returns to the last mode used.
    Q_INVOKABLE void toggleTracking();
    Q_INVOKABLE void setTracking(bool on);
    Q_INVOKABLE void resumeTracking();

    // Undo the last reset, profile change or profile deletion.
    Q_INVOKABLE void undo();
    Q_INVOKABLE void resetTracking();

    // Presets. savePreset returns the slot used, or -1 if all are full.
    Q_INVOKABLE int savePreset(const QString &name);
    Q_INVOKABLE void updatePreset(int id);
    Q_INVOKABLE void goToPreset(int id);
    Q_INVOKABLE void goToPresetIndex(int index);
    Q_INVOKABLE void renamePreset(int id, const QString &name);
    // Move a preset to a new place on the strip (display order only).
    Q_INVOKABLE void movePreset(int id, int toIndex);
    // Where the camera points when it turns on: -1 straight ahead, or a preset.
    Q_INVOKABLE void setStartupPreset(int id);
    Q_INVOKABLE void deletePreset(int id);
    Q_INVOKABLE QString thumbnailPath(int id) const;
    Q_INVOKABLE void thumbnailSaved(int id);

    // One-shot camera actions.
    Q_INVOKABLE void zoneStart(const QString &action); // "use-current", "go", "reset"
    Q_INVOKABLE void resetZone();
    Q_INVOKABLE void startup(const QString &action); // "use-current", "go", "reset"
    Q_INVOKABLE void resetImage();
    Q_INVOKABLE void factoryReset();

    // Profiles: named snapshots of camera settings.
    Q_INVOKABLE void saveProfile(const QString &name);
    Q_INVOKABLE void applyProfile(const QString &name);
    Q_INVOKABLE void deleteProfile(const QString &name);
    Q_INVOKABLE bool exportProfiles(const QUrl &file);
    Q_INVOKABLE int importProfiles(const QUrl &file);

    // For the D-Bus interface: run a gimbotctl command on the worker thread.
    void runCommand(const QStringList &args, std::function<void(int, QString)> reply);

signals:
    void connectedChanged();
    void deviceChanged();
    void valuesChanged();
    void rangesChanged();
    void presetsChanged();
    void positionChanged();
    void livePositionChanged();
    void profilesChanged();
    void trackingPausedChanged();
    void activeProfileChanged();
    void errorOccurred(const QString &message);
    // Something was changed that can be undone with undo().
    void undoAvailable(const QString &message);
    void notice(const QString &message);
    // A setting handled by the app itself changed (autostart, logging, ...).
    void appSettingChanged(const QString &key, const QVariant &value);

private:
    using Apply = std::function<bool(t2::Camera &, const QVariantMap &)>;
    enum class Kind { Status, Read, Pushed, App };
    struct Setting {
        Kind kind;
        QVariant def;
        QString label;
        Apply apply; // null for app-only settings
    };

    void defineSettings();
    void def(const QString &key, Kind kind, const QVariant &def, const QString &label, Apply apply = {});
    void sendToCamera(const QString &key);
    void touch(const QString &key);
    bool held(const QString &key) const;
    void applyStatus(const t2::Status &s);
    void mergeFromCamera(const QVariantMap &v, bool includeBootMode);
    QVariantMap gatherAll(t2::Camera &cam) const; // worker thread
    void onHotplug(const QString &serial, bool connected);
    void tryOpen(const QString &serial);
    void reloadPresets();
    void buildPresetList(const std::vector<t2::Preset> &list);
    void leaveTracking();
    t2::axis::Orientation orientation() const;
    float glide() const;
    void setPaused(bool on);
    void snapshotForUndo(const QStringList &keys, const QString &message);
    void call(const QString &key, const QString &what, std::function<bool(t2::Camera &)> fn, bool latest = true);
    void pollPosition();

    Worker m_worker;
    std::unique_ptr<t2::Camera> m_cam; // touched only on the worker thread
    QSettings m_settings;
    QTimer m_positionTimer;
    QTimer m_guideLightTimer;

    const bool m_simulated;
    bool m_usbAvailable = true;
    bool m_connected = false;
    bool m_opening = false;
    bool m_livePosition = false;
    bool m_positionPending = false;
    QString m_model, m_serial, m_firmware;
    double m_yaw = 0, m_pitch = 0; // SDK frame
    bool m_trackingPaused = false;
    bool m_internalSet = false; // set() called by the app itself, not the user
    QString m_activeProfile;
    QTimer m_resumeTimer;
    QTimer m_backupTimer;
    QVariantMap m_undo;    // settings to restore
    QString m_undoProfile; // deleted profile to restore
    QVariantMap m_undoProfileData;

    QHash<QString, Setting> m_table;
    QVariantMap m_values;
    QVariantMap m_ranges;
    QHash<QString, QElapsedTimer> m_touched;

    std::vector<t2::Preset> m_rawPresets;
    QVariantList m_presets;
    QHash<int, int> m_thumbRev;
};
