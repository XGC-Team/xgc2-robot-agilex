// Fixture only: pause the main thread at WallRate::sleep while ROS receipt and
// UDP IO continue. Commands can then be queued before the next tick's release.
#include <cstdlib>
#include <dlfcn.h>
#include <fcntl.h>
#include <string>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

extern "C" int nanosleep(const timespec *duration, timespec *remaining) {
  using Sleep = int (*)(const timespec *, timespec *);
  static const auto native_sleep = reinterpret_cast<Sleep>(dlsym(RTLD_NEXT, "nanosleep"));
  const char *request = std::getenv("SCOUT_TEST_LOOP_BARRIER");
  if (request && syscall(SYS_gettid) == getpid() && access(request, F_OK) == 0) {
    const std::string paused = std::string(request) + ".paused";
    const int fd = open(paused.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd >= 0) close(fd);
    const timespec poll{0, 1000000};
    while (access(request, F_OK) == 0) native_sleep(&poll, nullptr);
    unlink(paused.c_str());
  }
  return native_sleep(duration, remaining);
}
