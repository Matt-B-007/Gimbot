// Used when Gimbot is built without the OBSBOT SDK: no real cameras, only the
// simulated one (run with --fake). Lets the project build and test anywhere.
#include "camera.hpp"

namespace t2 {

bool Discovery::start(ChangeFn) { return false; }
void Discovery::stop() {}
std::vector<std::string> Discovery::cameras() { return {}; }
void Discovery::setVerbose(bool) {}
std::unique_ptr<Camera> openSdkCamera(const std::string &) { return nullptr; }

} // namespace t2
