// SPDX-License-Identifier: Apache-2.0
//
// Google apps for builds that ship without them (user builds have no root, no recovery).
//
//   opi4_gapps install   (after boot) look for MindTheGapps-*.zip on removable storage,
//                        unpack its system/ tree to /data/vendor/gapps and ask for a reboot.
//                        A file named REMOVE-GAPPS on the storage removes them again.
//   opi4_gapps mount     (post-fs-data, before zygote) overlay the unpacked tree on top of
//                        /product, /system and /system_ext directories, read-only.
//
// The verified system partitions are never written; the overlay only exists in RAM and
// disappears when /data/vendor/gapps is removed.

#include <dirent.h>
#include <fcntl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <unistd.h>

#include <string>
#include <vector>

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android-base/stringprintf.h>
#include <android-base/strings.h>
#include <ziparchive/zip_archive.h>

using android::base::EndsWith;
using android::base::StartsWith;
using android::base::StringPrintf;

static const std::string kBase = "/data/vendor/gapps";
static const std::string kRoot = kBase + "/root";      // active tree: <partition>/<dir>/...
static const std::string kStage = kBase + "/staging";  // being unpacked
static const std::string kStamp = kBase + "/installed";

// Directories GApps add files to. Every one of them must exist in the image (see opi4.mk).
static const char* kTargets[] = {
        "product/app",          "product/priv-app",
        "product/overlay",      "product/framework",
        "product/etc/permissions", "product/etc/sysconfig",
        "product/etc/default-permissions",
        "system/app",           "system/priv-app",       "system/etc/permissions",
        "system_ext/app",       "system_ext/priv-app",   "system_ext/etc/permissions",
};

// Stand-in apps that the Google ones replace (hidden with overlayfs whiteouts).
static const char* kHidden[] = {
        "product/priv-app/TvSampleLeanbackLauncher", "product/app/TvSampleLeanbackLauncher",
        "product/priv-app/TvProvision",              "product/app/TvProvision",
};

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

static bool MkdirP(const std::string& path, mode_t mode = 0755) {
    std::string cur;
    for (const auto& part : android::base::Split(path, "/")) {
        if (part.empty()) { cur = "/"; continue; }
        cur += (cur.empty() || cur == "/" ? "" : "/") + part;
        if (mkdir(cur.c_str(), mode) != 0 && errno != EEXIST) return false;
    }
    return true;
}

// ---------------------------------------------------------------------------- mount
static int DoMount() {
    if (access(kRoot.c_str(), F_OK) != 0) return 0;
    int n = 0;
    for (const char* t : kTargets) {
        std::string upper = kRoot + "/" + t;
        if (access(upper.c_str(), F_OK) != 0) continue;
        std::string target = std::string("/") + t;
        if (access(target.c_str(), F_OK) != 0) {
            LOG(WARNING) << target << " does not exist in the image, skipped";
            continue;
        }
        // Both layers read-only; files appear with the label of the image's own files.
        std::string opts = StringPrintf("lowerdir=%s:%s,context=u:object_r:system_file:s0",
                                        upper.c_str(), target.c_str());
        if (mount("overlay", target.c_str(), "overlay", MS_RDONLY, opts.c_str()) != 0) {
            PLOG(ERROR) << "overlay on " << target;
            continue;
        }
        n++;
    }
    LOG(INFO) << "Google apps overlay: " << n << " directories";
    android::base::SetProperty("vendor.opi4.gapps.active", n > 0 ? "1" : "0");
    return 0;
}

// -------------------------------------------------------------------------- install
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
    StartIteration(za, &cookie, "system/", "");
    ZipEntry64 entry;
    std::string name;
    int files = 0, r;
    bool ok = true;
    while ((r = Next(cookie, &entry, &name)) == 0) {
        // system/<partition>/<path> ; addon.d and init scripts are for recovery installs
        std::string rel = name.substr(strlen("system/"));
        if (EndsWith(rel, "/") || StartsWith(rel, "addon.d") || rel.find("/etc/init/") != std::string::npos)
            continue;
        if (!StartsWith(rel, "product/") && !StartsWith(rel, "system/") && !StartsWith(rel, "system_ext/"))
            continue;
        if (rel.find("..") != std::string::npos) { ok = false; break; }
        std::string out = kStage + "/" + rel;
        if (!MkdirP(android::base::Dirname(out))) { PLOG(ERROR) << out; ok = false; break; }
        android::base::unique_fd fd(open(out.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644));
        if (fd < 0 || ExtractEntryToFile(za, &entry, fd.get()) != 0) {
            LOG(ERROR) << "extract " << rel; ok = false; break;
        }
        files++;
    }
    EndIteration(cookie);
    CloseArchive(za);
    if (ok && files == 0) { LOG(ERROR) << zip << ": no system/ files"; ok = false; }
    LOG(INFO) << "unpacked " << files << " files from " << zip;
    if (!ok) return false;
    for (const char* h : kHidden) {   // overlayfs whiteout: char device 0/0
        std::string w = kStage + "/" + h;
        MkdirP(android::base::Dirname(w));
        if (mknod(w.c_str(), S_IFCHR | 0000, makedev(0, 0)) != 0) PLOG(WARNING) << w;
    }
    return true;
}

static void Reboot(const char* why) {
    LOG(INFO) << "rebooting: " << why;
    android::base::SetProperty("vendor.opi4.gapps.reboot", why);
}

static int DoInstall() {
    bool tv = android::base::GetProperty("ro.build.characteristics", "").find("tv") != std::string::npos;
    for (const auto& vol : Volumes()) {
        if (access((vol + "/REMOVE-GAPPS").c_str(), F_OK) == 0) {
            if (access(kRoot.c_str(), F_OK) != 0) return 0;
            RemoveTree(kRoot); unlink(kStamp.c_str());
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
            if (rename(kStage.c_str(), kRoot.c_str()) != 0) { PLOG(ERROR) << "rename"; return 1; }
            android::base::WriteStringToFile(stamp, kStamp);
            sync();
            android::base::SetProperty("vendor.opi4.gapps.state", "installed");
            Reboot("gapps-installed");
            return 0;
        }
    }
    return 0;
}

int main(int argc, char** argv) {
    android::base::InitLogging(argv, android::base::LogdLogger(android::base::SYSTEM));
    std::string mode = argc > 1 ? argv[1] : "";
    if (mode == "mount") return DoMount();
    if (mode == "install") {
        // Storage can be plugged in at any time: keep looking (cheap, a few directory reads).
        for (;;) {
            if (DoInstall() != 0) sleep(300);  // a broken zip: do not spin on it
            sleep(10);
        }
    }
    LOG(ERROR) << "usage: opi4_gapps mount|install";
    return 2;
}
