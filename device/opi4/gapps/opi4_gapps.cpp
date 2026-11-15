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
static const std::string kRoot = kBase + "/root";      // active tree: <partition>/<dir>/...
static const std::string kStage = kBase + "/staging";  // being unpacked
static const std::string kStamp = kBase + "/installed";

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
        if (mkdir(cur.c_str(), 0755) != 0 && errno != EEXIST) return false;
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
        if (fd < 0 || ExtractEntryToFile(za, &entry, fd.get()) != 0) {
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
            if (access(kRoot.c_str(), F_OK) != 0) return 0;
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
            LOG(INFO) << "installing Google apps from " << zip;
            android::base::SetProperty("vendor.opi4.gapps.state", "installing");
            RemoveTree(kStage);
            if (!Unpack(zip)) {
                RemoveTree(kStage);
                android::base::SetProperty("vendor.opi4.gapps.state", "failed");
                return 1;
            }
            RemoveTree(kRoot);
            if (rename(kStage.c_str(), kRoot.c_str()) != 0) {
                PLOG(ERROR) << "rename";
                return 1;
            }
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
    // Storage can be plugged in at any time: keep looking (a few directory reads).
    for (;;) {
        if (DoInstall() != 0) sleep(300);  // a broken zip: do not spin on it
        sleep(10);
    }
}
