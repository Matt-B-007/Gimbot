// SPDX-License-Identifier: MIT
// Behaviour of the app's controller with the simulated camera: the tracking
// switch, pausing on manual moves, resume, undo and the active profile.
#include "controller.hpp"

#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

class ControllerTest : public QObject {
    Q_OBJECT
    Controller *cam = nullptr;

    void waitConnected()
    {
        QTRY_VERIFY_WITH_TIMEOUT(cam->connected(), 5000);
        QTest::qWait(300);
    }
    int mode() const { return cam->values().value("mode").toInt(); }

private slots:
    void init()
    {
        QStandardPaths::setTestModeEnabled(true);
        QSettings().clear();
        cam = new Controller(true);
        cam->start();
        waitConnected();
    }
    void cleanup()
    {
        delete cam;
        cam = nullptr;
    }

    void switchRemembersLastMode()
    {
        cam->set("mode", 3); // Hand
        QCOMPARE(mode(), 3);
        cam->setTracking(false);
        QCOMPARE(mode(), 0);
        QVERIFY(!cam->trackingPaused());
        cam->setTracking(true);
        QCOMPARE(mode(), 3); // back to Hand, not Person
        cam->toggleTracking();
        QCOMPARE(mode(), 0);
        cam->toggleTracking();
        QCOMPARE(mode(), 3);
    }

    void manualMovePausesAndResumes()
    {
        cam->set("mode", 1); // Group
        cam->aimAt(0.8, 0.2);
        QCOMPARE(mode(), 0);
        QVERIFY(cam->trackingPaused());
        cam->resumeTracking();
        QCOMPARE(mode(), 1);
        QVERIFY(!cam->trackingPaused());
        // Turning tracking off yourself is not "paused".
        cam->move(1, 0);
        cam->stopMove();
        QVERIFY(cam->trackingPaused());
        cam->setTracking(false);
        QVERIFY(!cam->trackingPaused());
    }

    void autoResume()
    {
        cam->set("autoResume", true);
        cam->set("autoResumeSeconds", 1);
        cam->set("mode", 2);
        cam->recenter();
        QVERIFY(cam->trackingPaused());
        QTRY_COMPARE_WITH_TIMEOUT(mode(), 2, 3000);
        QVERIFY(!cam->trackingPaused());
    }

    void screenDirections()
    {
        // The dial and live angles are in screen terms whatever the mirror says.
        for (bool mirrored : {false, true}) {
            cam->set("mirrored", mirrored);
            cam->aimAbsolute(30, 10); // 30° right, 10° up
            QCOMPARE(cam->pan(), 30.0);
            QCOMPARE(cam->tilt(), 10.0);
            QCOMPARE(cam->rawPitch(), -10.0); // SDK: down is positive
            QCOMPARE(cam->rawYaw(), mirrored ? 30.0 : -30.0);
        }
    }

    void undoReset()
    {
        cam->set("brightness", 80);
        cam->set("wbMode", 2);
        QSignalSpy spy(cam, &Controller::undoAvailable);
        cam->resetImage();
        QCOMPARE(spy.count(), 1);
        QCOMPARE(cam->values().value("wbMode").toInt(), 0);
        QVERIFY(cam->values().value("brightness").toInt() != 80);
        cam->undo();
        QCOMPARE(cam->values().value("brightness").toInt(), 80);
        QCOMPARE(cam->values().value("wbMode").toInt(), 2);
    }

    void undoProfileDelete()
    {
        cam->saveProfile("Meetings");
        cam->deleteProfile("Meetings");
        QVERIFY(!cam->profiles().contains("Meetings"));
        cam->undo();
        QVERIFY(cam->profiles().contains("Meetings"));
    }

    void reorderPresets()
    {
        QTRY_VERIFY_WITH_TIMEOUT(cam->presets().size() >= 2, 3000);
        const int first = cam->presets()[0].toMap()["id"].toInt();
        const int second = cam->presets()[1].toMap()["id"].toInt();
        cam->movePreset(first, 1);
        QCOMPARE(cam->presets()[0].toMap()["id"].toInt(), second);
        QCOMPARE(cam->presets()[1].toMap()["id"].toInt(), first);
        QCOMPARE(cam->presets()[1].toMap()["index"].toInt(), 1); // Ctrl+2 follows the new order
        cam->movePreset(first, -5);                                // clamped to the start
        QCOMPARE(cam->presets()[0].toMap()["id"].toInt(), first);
    }

    void startupPreset()
    {
        QTRY_VERIFY_WITH_TIMEOUT(cam->presets().size() >= 1, 3000);
        const int id = cam->presets()[0].toMap()["id"].toInt();
        cam->set("mode", 2);
        cam->setStartupPreset(id);
        QCOMPARE(cam->values().value("startupPreset").toInt(), id);
        QCOMPARE(mode(), 0); // moving to the preset pauses tracking
        cam->setStartupPreset(-1);
        QCOMPARE(cam->values().value("startupPreset").toInt(), -1);
    }

    void activeProfile()
    {
        cam->set("fov", 2);
        cam->saveProfile("Streaming");
        cam->set("fov", 0);
        cam->applyProfile("Streaming");
        QCOMPARE(cam->activeProfile(), QString("Streaming"));
        QCOMPARE(cam->values().value("fov").toInt(), 2);
        cam->set("fov", 1); // any change leaves the profile
        QCOMPARE(cam->activeProfile(), QString());
    }
};

QTEST_MAIN(ControllerTest)
#include "test_controller.moc"
