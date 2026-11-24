// Text commands shared by gimbotctl and the app's D-Bus interface, so
// `gimbotctl track person` works the same whether it talks to the camera
// directly or through the running Gimbot app.
#pragma once

#include "camera.hpp"

#include <string>
#include <vector>

namespace t2 {

// Runs one command (e.g. {"zoom", "40"}). Writes any output or error text
// to `out`. Returns a process exit code: 0 success, 1 failure, 2 bad usage.
int runCommand(Camera &cam, const std::vector<std::string> &args, std::string &out);

// The help text for every command runCommand understands.
const char *commandHelp();

} // namespace t2
