// SPDX-License-Identifier: Apache-2.0
//
// Google apps for images that ship without them (user builds have no root, no recovery).
//
// opi4_gapps (service, after boot) watches removable storage for MindTheGapps-*.zip,
// unpacks its system/ tree to /data/vendor/gapps/root and asks init for a reboot.
// A file named REMOVE-GAPPS on the storage removes them again.
// init overlays the tree on the app directories at post-fs-data (opi4_gapps.rc).
// The verified system partitions are never written.

#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include <memory>
#include <string>
#include <vector>

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android-base/stringprintf.h>
#include <android-base/strings.h>
#include <android-base/unique_fd.h>
#include <ziparchive/zip_archive.h>

using android::base::EndsWith;
using android::base::StartsWith;
using android::base::StringPrintf;

static const std::string kBase = "/data/vendor/gapps";
static const std::string kImage = kBase + "/gapps.img";  // ext4: <partition>/<dir>/..., hide/
static const std::string kStage = kBase + "/staging";    // unpacked zip, turned into the image
static const std::string kStamp = kBase + "/installed";
// Legacy layout (plain directory); removed when found.
static const std::string kRoot = kBase + "/root";

// The overlays' backing files must not live on /data: kernels >= 6.10 check the mounter's
// (init's) execute right on the backing file when an app maps a library, and init may not
// execute data files. So the tree goes into an ext4 image that init loop-mounts with the
// system_file label (opi4_gapps.rc).
static bool Run(std::vector<std::string> args) {
    std::vector<char*> argv;
    for (auto& a : args) argv.push_back(a.data());
    argv.push_back(nullptr);
    pid_t pid = fork();
    if (pid == 0) {
        execv(argv[0], argv.data());
        _exit(127);
    }
    int status = 0;
    if (pid < 0 || waitpid(pid, &status, 0) != pid || !WIFEXITED(status) || WEXITSTATUS(status)) {
        LOG(ERROR) << android::base::Join(args, ' ') << " failed, status " << status;
        return false;
    }
    return true;
}

static uint64_t TreeBytes(const std::string& path) {
    struct stat st;
    if (lstat(path.c_str(), &st) != 0) return 0;
    if (!S_ISDIR(st.st_mode)) return (st.st_size + 4095) / 4096 * 4096;
    uint64_t sum = 4096;
    std::unique_ptr<DIR, decltype(&closedir)> d(opendir(path.c_str()), closedir);
    if (!d) return sum;
    while (dirent* e = readdir(d.get())) {
        std::string n = e->d_name;
        if (n != "." && n != "..") sum += TreeBytes(path + "/" + n);
    }
    return sum;
}

static bool MakeImage() {
    uint64_t bytes = TreeBytes(kStage);
    uint64_t blocks = (bytes + bytes / 10) / 4096 + 16384;  // +10% metadata, +64 MiB
    std::string tmp = kImage + ".new";
    unlink(tmp.c_str());
    if (!Run({"/vendor/bin/mke2fs", "-q", "-t", "ext4", "-b", "4096", "-O", "^has_journal",
              "-m", "0", "-L", "gapps", tmp, std::to_string(blocks)}) ||
        !Run({"/vendor/bin/e2fsdroid", "-f", kStage, "-a", "/mnt/vendor/gapps", tmp})) {
        unlink(tmp.c_str());
        return false;
    }
    chmod(tmp.c_str(), 0644);
    return rename(tmp.c_str(), kImage.c_str()) == 0;
}

static bool RemoveTree(const std::string& path) {
    struct stat st;
    if (lstat(path.c_str(), &st) != 0) return errno == ENOENT;
    if (S_ISDIR(st.st_mode)) {
        std::unique_ptr<DIR, decltype(&closedir)> d(opendir(path.c_str()), closedir);
        if (!d) return false;
        while (dirent* e = readdir(d.get())) {
            std::string n = e->d_name;
            if (n == "." || n == "..") continue;
            if (!RemoveTree(path + "/" + n)) return false;
        }
        return rmdir(path.c_str()) == 0;
    }
    return unlink(path.c_str()) == 0;
}

static bool MkdirP(const std::string& path) {
    std::string cur;
    for (const auto& part : android::base::Split(path, "/")) {
        if (part.empty()) continue;
        cur += "/" + part;
        if (mkdir(cur.c_str(), 0755) != 0) {
            if (errno != EEXIST) return false;
        } else if (StartsWith(cur, kStage) && chmod(cur.c_str(), 0755) != 0) {
            return false;  // merged overlay dirs take these modes: must be world-searchable
        }
    }
    return true;
}

static std::vector<std::string> Volumes() {
    std::vector<std::string> v;
    std::unique_ptr<DIR, decltype(&closedir)> d(opendir("/mnt/media_rw"), closedir);
    if (!d) return v;
    while (dirent* e = readdir(d.get())) {
        if (e->d_name[0] != '.') v.push_back(std::string("/mnt/media_rw/") + e->d_name);
    }
    return v;
}

static bool WantedZip(const std::string& name, bool tv) {
    if (!StartsWith(name, "MindTheGapps-") || !EndsWith(name, ".zip")) return false;
    if (name.find("arm64") == std::string::npos) return false;
    return (name.find("ATV") != std::string::npos) == tv;
}

static bool Unpack(const std::string& zip) {
    ZipArchiveHandle za;
    if (int r = OpenArchive(zip.c_str(), &za); r != 0) {
        LOG(ERROR) << zip << ": " << ErrorCodeString(r);
        CloseArchive(za);
        return false;
    }
    void* cookie;
    if (StartIteration(za, &cookie, "system/", "") != 0) {
        CloseArchive(za);
        return false;
    }
    ZipEntry64 entry;
    std::string name;
    int files = 0;
    bool ok = true;
    while (Next(cookie, &entry, &name) == 0) {
        // system/<partition>/<path>; addon.d and init scripts belong to recovery installs
        std::string rel = name.substr(strlen("system/"));
        if (EndsWith(rel, "/") || StartsWith(rel, "addon.d") ||
            rel.find("/etc/init/") != std::string::npos)
            continue;
        if (!StartsWith(rel, "product/") && !StartsWith(rel, "system/") &&
            !StartsWith(rel, "system_ext/"))
            continue;
        if (rel.find("..") != std::string::npos) { ok = false; break; }
        std::string out = kStage + "/" + rel;
        if (!MkdirP(android::base::Dirname(out))) { PLOG(ERROR) << out; ok = false; break; }
        android::base::unique_fd fd(open(out.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644));
        // The overlay shows the files with these modes: system_server (not root) must read them.
        if (fd < 0 || fchmod(fd.get(), 0644) != 0 || ExtractEntryToFile(za, &entry, fd.get()) != 0) {
            LOG(ERROR) << "extract " << rel;
            ok = false;
            break;
        }
        files++;
    }
    EndIteration(cookie);
    CloseArchive(za);
    if (ok && files == 0) { LOG(ERROR) << zip << ": no system/ files"; ok = false; }
    LOG(INFO) << "unpacked " << files << " files from " << zip;
    // empty directory that init mounts over the stand-in launcher and setup apps
    return ok && MkdirP(kStage + "/hide");
}

static void Reboot(const char* why) {
    LOG(INFO) << "rebooting: " << why;
    android::base::SetProperty("vendor.opi4.gapps.reboot", why);
}

static int DoInstall() {
    bool tv = android::base::GetProperty("ro.build.characteristics", "").find("tv") !=
              std::string::npos;
    for (const auto& vol : Volumes()) {
        if (access((vol + "/REMOVE-GAPPS").c_str(), F_OK) == 0) {
            if (access(kImage.c_str(), F_OK) != 0 && access(kRoot.c_str(), F_OK) != 0) return 0;
            unlink(kImage.c_str());
            RemoveTree(kRoot);
            unlink(kStamp.c_str());
            sync();
            Reboot("gapps-removed");
            return 0;
        }
        std::unique_ptr<DIR, decltype(&closedir)> d(opendir(vol.c_str()), closedir);
        if (!d) continue;
        while (dirent* e = readdir(d.get())) {
            std::string name = e->d_name;
            if (!WantedZip(name, tv)) continue;
            std::string zip = vol + "/" + name;
            struct stat st;
            if (stat(zip.c_str(), &st) != 0) continue;
            std::string stamp = StringPrintf("%s %lld", name.c_str(), (long long)st.st_size);
            std::string old;
            if (android::base::ReadFileToString(kStamp, &old) && old == stamp) return 0;
            // still being copied onto the storage? wait until the size stops changing
            sleep(5);
            struct stat st2;
            if (stat(zip.c_str(), &st2) != 0 || st2.st_size != st.st_size ||
                st2.st_mtime != st.st_mtime)
                return 0;
            LOG(INFO) << "installing Google apps from " << zip;
            android::base::SetProperty("vendor.opi4.gapps.state", "installing");
            RemoveTree(kStage);
            if (!Unpack(zip)) {
                RemoveTree(kStage);
                android::base::SetProperty("vendor.opi4.gapps.state", "failed");
                return 1;
            }
            bool imaged = MakeImage();
            RemoveTree(kStage);
            if (!imaged) {
                android::base::SetProperty("vendor.opi4.gapps.state", "failed");
                return 1;
            }
            RemoveTree(kRoot);
            android::base::WriteStringToFile(stamp, kStamp);
            sync();
            android::base::SetProperty("vendor.opi4.gapps.state", "installed");
            Reboot("gapps-installed");
            return 0;
        }
    }
    return 0;
}

int main(int /*argc*/, char** argv) {
    android::base::InitLogging(argv, android::base::LogdLogger(android::base::SYSTEM));
    umask(022);  // init starts services with 077; the unpacked tree must be readable by all
    // Storage can be plugged in at any time: keep looking (a few directory reads).
    for (;;) {
        if (DoInstall() != 0) sleep(300);  // a broken zip: do not spin on it
        sleep(10);
    }
}
