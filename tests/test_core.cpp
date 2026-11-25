// Tests that run without a camera: the command interpreter against the fake
// camera, and the update checker's version comparison.
#include "camera.hpp"
#include "commands.hpp"
#include "previewformat.hpp"
#include "updater.hpp"

#include <QtTest>

class CoreTest : public QObject {
    Q_OBJECT

    int run(t2::Camera &cam, std::vector<std::string> args, std::string *out = nullptr)
    {
        std::string text;
        const int code = t2::runCommand(cam, args, text);
        if (out) *out = text;
        return code;
    }

private slots:
    void trackingAndZoom()
    {
        auto cam = t2::openFakeCamera();
        QCOMPARE(run(*cam, {"track", "group"}), 0);
        QCOMPARE(cam->status().mode, t2::Mode::Group);
        QCOMPARE(run(*cam, {"track", "person", "close"}), 0);
        QCOMPARE(cam->status().framing, int(t2::Framing::CloseUp));
        QCOMPARE(run(*cam, {"zoom", "40"}), 0);
        QCOMPARE(cam->status().zoomPercent, 40);
        QCOMPARE(run(*cam, {"zoom", "400"}), 0);
        QCOMPARE(cam->status().zoomPercent, 100); // clamped
    }

    void gimbal()
    {
        // gimbotctl uses screen directions: up and right are positive.
        auto cam = t2::openFakeCamera();
        cam->setMirror(false);
        QCOMPARE(run(*cam, {"aim", "10", "-20"}), 0); // 10° up, 20° left
        t2::GimbalPos p;
        QVERIFY(cam->position(p));
        QCOMPARE(p.pitch, -10.f); // SDK frame: down is positive
        QCOMPARE(p.yaw, 20.f);    // SDK frame: camera's left is positive
        QCOMPARE(run(*cam, {"turn", "5", "5"}), 0);
        QVERIFY(cam->position(p));
        QCOMPARE(p.pitch, -15.f);
        QCOMPARE(p.yaw, 15.f);
        QCOMPARE(run(*cam, {"center"}), 0);
        QVERIFY(cam->position(p));
        QCOMPARE(p.yaw, 0.f);
        // A mirrored picture swaps left and right.
        cam->setMirror(true);
        QCOMPARE(run(*cam, {"aim", "0", "-20"}), 0);
        QVERIFY(cam->position(p));
        QCOMPARE(p.yaw, -20.f);
    }

    void sdkFrameMatchesDocs()
    {
        // OBSBOT documents the Tiny 2 angles as "down is positive" and
        // "right is positive when facing the device" (the camera's left,
        // which is the left of an unmirrored picture).
        QCOMPARE(t2::axis::kPitchPerUp, -1.0);
        QCOMPARE(t2::axis::kYawPerRight, -1.0);
    }

    void allControlsAgree()
    {
        // Whatever the mirror and invert settings, every way of moving the
        // camera must go the same way on screen.
        for (int bits = 0; bits < 8; ++bits) {
            t2::axis::Orientation o;
            o.mirrored = bits & 1;
            o.invertPan = bits & 2;
            o.invertTilt = bits & 4;
            auto cam = t2::openFakeCamera();
            t2::GimbalPos p;
            auto screen = [&] {
                cam->position(p);
                return QPointF(t2::axis::screenFromYaw(p.yaw, o), t2::axis::screenFromPitch(p.pitch, o));
            };

            // Click-to-aim at the top-right corner.
            cam->moveTo(0, 0);
            QVERIFY(cam->aimAt(1.0, 0.0, o));
            QPointF s = screen();
            QVERIFY2(s.x() > 0 && s.y() > 0, qPrintable(QString("aimAt, case %1").arg(bits)));

            // Holding up and right (arrow keys, drag-to-steer).
            cam->moveTo(0, 0);
            cam->move(t2::axis::pitchFromScreen(40, o), t2::axis::yawFromScreen(40, o));
            QTest::qWait(150);
            cam->move(0, 0);
            s = screen();
            QVERIFY2(s.x() > 0 && s.y() > 0, qPrintable(QString("move, case %1").arg(bits)));

            // The aim dial (absolute angles).
            cam->moveTo(float(t2::axis::pitchFromScreen(20, o)), float(t2::axis::yawFromScreen(30, o)));
            s = screen();
            QCOMPARE(s, QPointF(30, 20));
        }
    }

    void aimAtCentreDoesNotMove()
    {
        auto cam = t2::openFakeCamera();
        const t2::axis::Orientation o;
        cam->moveTo(5, 30);
        QVERIFY(cam->aimAt(0.5, 0.5, o));
        t2::GimbalPos p;
        cam->position(p);
        QCOMPARE(p.pitch, 5.f);
        QCOMPARE(p.yaw, 30.f);
        QVERIFY(cam->aimAt(1.0, 0.5, o)); // right edge: turns by about half the FOV
        cam->position(p);
        QVERIFY(qAbs(p.yaw - 30.f) > 30.f && qAbs(p.yaw - 30.f) < 45.f);
    }

    void glideToPreset()
    {
        auto cam = t2::openFakeCamera();
        QVERIFY(cam->glideToPreset(1, 30, 3)); // "Whiteboard": yaw 35, zoom 1.0
        t2::GimbalPos p;
        cam->position(p);
        QCOMPARE(p.yaw, 35.f);
        QCOMPARE(cam->status().zoomPercent, 0);
        QVERIFY(cam->glideToPreset(0, 30, 3)); // "Desk": zoom 1.2 = 20%
        QCOMPARE(cam->status().zoomPercent, 20);
        QVERIFY(!cam->glideToPreset(9, 30, 3));
    }

    void presets()
    {
        auto cam = t2::openFakeCamera();
        QCOMPARE(run(*cam, {"preset", "save", "2", "Couch"}), 0);
        QCOMPARE(run(*cam, {"preset", "rename", "2", "Sofa"}), 0);
        std::string out;
        QCOMPARE(run(*cam, {"preset", "list"}, &out), 0);
        QVERIFY(out.find("Sofa") != std::string::npos);
        QCOMPARE(run(*cam, {"preset", "delete", "2"}), 0);
        QCOMPARE(run(*cam, {"preset", "go", "2"}), 1); // gone
    }

    void imageAndVoice()
    {
        auto cam = t2::openFakeCamera();
        QCOMPARE(run(*cam, {"exposure", "1/120"}), 0);
        bool ae = true;
        int sh = 0;
        cam->exposure(ae, sh);
        QVERIFY(!ae);
        QCOMPARE(QString(t2::shutter::label(sh)), QString("1/120"));
        QCOMPARE(run(*cam, {"wb", "4800"}), 0);
        int mode = 0, k = 0;
        cam->whiteBalance(mode, k);
        QCOMPARE(mode, t2::wb::Manual);
        QCOMPARE(k, 4800);
        QCOMPARE(run(*cam, {"voice", "off"}), 0);
        QCOMPARE(cam->status().voiceMask, 0);
        QCOMPARE(run(*cam, {"area", "set", "-30", "40", "-10", "20"}), 0);
        t2::Zone z;
        cam->zone(z);
        QCOMPARE(z.yawMax, 40.f);
    }

    void shutterLabels()
    {
        QCOMPARE(QString(t2::shutter::label(t2::shutter::First)), QString("1/8000"));
        QCOMPARE(QString(t2::shutter::label(t2::shutter::Last)), QString("1/2"));
        QCOMPARE(QString(t2::shutter::label(30)), QString("1/60"));
        QCOMPARE(QString(t2::shutter::label(t2::shutter::Last + 1)), QString("auto"));
    }

    void badInput()
    {
        auto cam = t2::openFakeCamera();
        QCOMPARE(run(*cam, {"track", "cats"}), 2);
        QCOMPARE(run(*cam, {"factory-reset"}), 2); // needs --yes
        QCOMPARE(run(*cam, {}), 2);
    }

    void previewFormat()
    {
        using F = preview::Format;
        const std::vector<F> tiny2 = {{640, 360, 30, false},   {1280, 720, 30, true},  {1280, 720, 10, false},
                                      {1920, 1080, 30, true},  {1920, 1080, 5, false}, {3840, 2160, 30, true},
                                      {3840, 2160, 15, false}, {1920, 1080, 60, true}};
        // Auto: the smallest smooth format that covers the preview, never below 720p.
        QCOMPARE(preview::choose(tiny2, 400, 0), 1);   // 720p30
        QCOMPARE(preview::choose(tiny2, 900, 0), 7);   // 1080p60 beats 1080p30
        QCOMPARE(preview::choose(tiny2, 1500, 0), 7);  // Auto stops at 1080p (60 fps), never 4K
        QCOMPARE(preview::choose(tiny2, 5000, 0), 7);
        QCOMPARE(preview::choose({{1280, 720, 30, true}}, 1500, 0), 0); // nothing bigger: what there is
        // Fixed choices skip slow raw modes.
        QCOMPARE(preview::choose(tiny2, 400, 2), 7);
        QCOMPARE(preview::choose(tiny2, 400, 3), 5);
        // A raw format wins a tie with MJPEG.
        QCOMPARE(preview::choose({{1280, 720, 30, true}, {1280, 720, 30, false}}, 400, 0), 1);
        // Only slow formats: still pick one.
        QCOMPARE(preview::choose({{640, 480, 15, false}}, 400, 0), 0);
        QCOMPARE(preview::choose({}, 400, 0), -1);
    }

    void versions()
    {
        QCOMPARE(Updater::compareVersions("1.2.0", "1.10.0"), -1);
        QCOMPARE(Updater::compareVersions("v1.3.0", "1.3.0"), 0);
        QCOMPARE(Updater::compareVersions("1.3.0-beta.2", "1.3.0"), -1);
        QCOMPARE(Updater::compareVersions("1.3.0-beta.10", "1.3.0-beta.9"), 1);
        QCOMPARE(Updater::compareVersions("1.4.0-beta.1", "1.3.9"), 1);
    }
};

QTEST_GUILESS_MAIN(CoreTest)
#include "test_core.moc"
