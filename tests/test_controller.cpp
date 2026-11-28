// SPDX-License-Identifier: MIT
// Behaviour of the app's controller with the simulated camera: the tracking
// switch, pausing on manual moves, resume, undo and the active profile.
#include "controller.hpp"

#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

#include <cmath>

class ControllerTest : public QObject
{
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

    // The status light's level comes from the camera status (read-only), and
    // the sleep picture can be chosen and mirrored.
    void statusLightAndSleepPicture()
    {
        QTRY_COMPARE(cam->values().value("ledLevel").toInt(), 2);
        QVERIFY(cam->values().value("hasSleepPicture").toBool());
        cam->set("sleepPicture", 2);
        QTRY_COMPARE(cam->values().value("sleepPicture").toInt(), 2);
        cam->set("sleepPictureMirrored", true);
        QTRY_VERIFY(cam->values().value("sleepPictureMirrored").toBool());
    }

    // Picture <-> angles from where the camera points now, so a zone drawn on
    // the picture lands on the right angles, mirrored or not.
    void pictureAnglesFollowPosition()
    {
        const QPointF centre = cam->pictureFromAngles(cam->rawYaw(), cam->rawPitch());
        QVERIFY(qAbs(centre.x() - 0.5) < 1e-6 && qAbs(centre.y() - 0.5) < 1e-6);
        for (bool mirrored : {false, true}) {
            cam->set("mirrored", mirrored);
            QTRY_COMPARE(cam->values().value("mirrored").toBool(), mirrored);
            const auto a = cam->anglesFromPicture(0.8, 0.3);
            const QPointF back = cam->pictureFromAngles(a["yaw"].toDouble(), a["pitch"].toDouble());
            QVERIFY(qAbs(back.x() - 0.8) < 1e-6 && qAbs(back.y() - 0.3) < 1e-6);
            // Above the centre is camera pitch up, which the SDK calls negative.
            QVERIFY(a["pitch"].toDouble() < cam->rawPitch());
            // Right of centre: negative SDK yaw unmirrored, positive mirrored.
            const double dyaw = a["yaw"].toDouble() - cam->rawYaw();
            QVERIFY2(mirrored ? dyaw > 0 : dyaw < 0, qPrintable(QString::number(dyaw)));
        }
    }

    void zoneEdgesFromPicture()
    {
        cam->set("mirrored", false);
        QTRY_VERIFY(!cam->values().value("mirrored").toBool());
        cam->recenter();
        // A box in the middle of the picture: edges inside the camera's reach,
        // in order whichever corners it's given, and whole degrees.
        cam->setZoneFromPicture(0.75, 0.7, 0.25, 0.3);
        const auto v = [this](const char *k) { return cam->values().value(k).toDouble(); };
        QTRY_VERIFY(v("zoneYawMin") < 0 && v("zoneYawMax") > 0);
        QVERIFY(v("zonePitchMin") < 0 && v("zonePitchMax") > 0);
        QCOMPARE(v("zoneYawMin"), std::round(v("zoneYawMin")));
        // Turned far to one side, the whole picture reaches past the camera's
        // limit: that edge is held at it, the other isn't.
        cam->aimAbsolute(115, 0); // screen right
        cam->setZoneFromPicture(0, 0, 1, 1);
        QTRY_COMPARE(v("zoneYawMin"), -120.0); // right is negative SDK yaw unmirrored
        QVERIFY(v("zoneYawMax") > -120 && v("zoneYawMax") < 120);
        QVERIFY(v("zonePitchMin") >= -90 && v("zonePitchMax") <= 90);
        cam->recenter();
    }

    void zoneKeepsSidesThatWereNotMoved()
    {
        cam->set("mirrored", false);
        cam->recenter();
        const auto v = [this](const char *k) { return cam->values().value(k).toDouble(); };
        cam->setZoneEdges(-120, 120, -90, 90); // the whole range: every edge is far outside the picture
        QTRY_COMPARE(v("zoneYawMax"), 120.0);
        // Only the left side was dragged. The others can't be read back from
        // the picture (it stops short of 90 degrees), so they must not change.
        cam->setZoneFromPicture(0.3, 0.3, 0.7, 0.7, true, false, false, false);
        QTRY_VERIFY(std::abs(v("zoneYawMin")) < 120 || std::abs(v("zoneYawMax")) < 120);
        const bool minMoved = std::abs(v("zoneYawMin")) < 120;
        QCOMPARE(minMoved ? v("zoneYawMax") : v("zoneYawMin"), minMoved ? 120.0 : -120.0);
        QCOMPARE(v("zonePitchMin"), -90.0);
        QCOMPARE(v("zonePitchMax"), 90.0);
        cam->setZoneEdges(-120, 120, -90, 90);
    }

    void zoneEdgesStayInOrder()
    {
        const auto v = [this](const char *k) { return cam->values().value(k).toDouble(); };
        // The camera must never be handed a left edge past the right one, not
        // even between two steps: watch every change on the way.
        bool insideOut = false;
        const auto watch = connect(cam, &Controller::valuesChanged, this, [&] {
            if (v("zoneYawMin") > v("zoneYawMax") || v("zonePitchMin") > v("zonePitchMax")) insideOut = true;
        });
        cam->setZoneEdges(-100, -70, -80, -60);
        cam->setZoneEdges(60, 80, 40, 70);     // all the way across
        cam->setZoneEdges(-90, -85, -20, -10); // and back
        cam->setZoneEdges(50, -50, 30, -30);   // given the wrong way round
        QTRY_COMPARE(v("zoneYawMin"), -50.0);
        QCOMPARE(v("zoneYawMax"), 50.0);
        QCOMPARE(v("zonePitchMin"), -30.0);
        QCOMPARE(v("zonePitchMax"), 30.0);
        cam->setZoneEdges(-500, 500, -500, 500); // held at the camera's reach
        QTRY_COMPARE(v("zoneYawMax"), 120.0);
        QCOMPARE(v("zonePitchMin"), -90.0);
        disconnect(watch);
        QVERIFY(!insideOut);
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
        cam->movePreset(first, -5);                              // clamped to the start
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
