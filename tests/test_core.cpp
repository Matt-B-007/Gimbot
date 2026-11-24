// Tests that run without a camera: the command interpreter against the fake
// camera, and the update checker's version comparison.
#include "camera.hpp"
#include "commands.hpp"
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
        auto cam = t2::openFakeCamera();
        QCOMPARE(run(*cam, {"aim", "10", "-20"}), 0);
        t2::GimbalPos p;
        QVERIFY(cam->position(p));
        QCOMPARE(p.pitch, 10.f);
        QCOMPARE(p.yaw, -20.f);
        QCOMPARE(run(*cam, {"turn", "5", "5"}), 0);
        QVERIFY(cam->position(p));
        QCOMPARE(p.yaw, -15.f);
        QCOMPARE(run(*cam, {"center"}), 0);
        QVERIFY(cam->position(p));
        QCOMPARE(p.yaw, 0.f);
    }

    void aimAtCentreDoesNotMove()
    {
        auto cam = t2::openFakeCamera();
        cam->moveTo(5, 30);
        QVERIFY(cam->aimAt(0.5, 0.5));
        t2::GimbalPos p;
        cam->position(p);
        QCOMPARE(p.pitch, 5.f);
        QCOMPARE(p.yaw, 30.f);
        QVERIFY(cam->aimAt(1.0, 0.5)); // right edge: turns by about half the FOV
        cam->position(p);
        QVERIFY(qAbs(p.yaw - 30.f) > 30.f && qAbs(p.yaw - 30.f) < 45.f);
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

    void badInput()
    {
        auto cam = t2::openFakeCamera();
        QCOMPARE(run(*cam, {"track", "cats"}), 2);
        QCOMPARE(run(*cam, {"factory-reset"}), 2); // needs --yes
        QCOMPARE(run(*cam, {}), 2);
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
