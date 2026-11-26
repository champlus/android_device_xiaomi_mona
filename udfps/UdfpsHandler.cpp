/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "UdfpsHandler.xiaomi_mona"

#include <aidl/android/hardware/biometrics/fingerprint/BnFingerprint.h>
#include <android-base/logging.h>
#include <android-base/unique_fd.h>

#include <fcntl.h>
#include <poll.h>
#include <atomic>
#include <chrono>
#include <fstream>
#include <thread>

#include "UdfpsHandler.h"

// Fingerprint hwmodule commands
#define COMMAND_NIT 10
#define PARAM_NIT_UDFPS 1
#define PARAM_NIT_NONE 0

#define COMMAND_FOD_PRESS_STATUS 1
#define PARAM_FOD_PRESSED 1
#define PARAM_FOD_RELEASED 0

// Touchscreen and HBM
#define FOD_HBM_PATH "/sys/devices/platform/soc/soc:qcom,dsi-display-primary/fod_hbm"
#define FOD_UI_PATH "/sys/devices/platform/soc/soc:qcom,dsi-display-primary/fod_ui"
#define FOD_FINGER_DOWN_PATH "/sys/devices/virtual/touch/touch_dev/fod_finger_down"

#define FOD_HBM_OFF 0
#define FOD_HBM_ON 1

#define FOD_FINGER_UP 0
#define FOD_FINGER_DOWN 1

using ::aidl::android::hardware::biometrics::fingerprint::AcquiredInfo;

template <typename T>
static void set(const std::string& path, const T& value) {
    std::ofstream file(path);
    if (!file.is_open()) {
        LOG(ERROR) << "failed to open " << path;
        return;
    }
    file << value;
    if (!file.good()) {
        LOG(ERROR) << "failed to write " << value << " to " << path;
    }
}

static bool readBool(int fd) {
    char c;
    int rc;

    rc = lseek(fd, 0, SEEK_SET);
    if (rc) {
        LOG(ERROR) << "failed to seek fd, err: " << rc;
        return false;
    }

    rc = read(fd, &c, sizeof(char));
    if (rc != 1) {
        LOG(ERROR) << "failed to read bool from fd, err: " << rc;
        return false;
    }

    return c != '0';
}

class XiaomiMonaUdfpsHandler : public UdfpsHandler {
  public:
    void init(fingerprint_device_t* device) override {
        mDevice = device;

        std::thread([this]() {
            android::base::unique_fd fd(open(FOD_UI_PATH, O_RDONLY));
            if (fd < 0) {
                LOG(ERROR) << "failed to open " << FOD_UI_PATH << " , err: " << fd;
                return;
            }

            struct pollfd fodUiPoll = {
                    .fd = fd.get(),
                    .events = POLLERR | POLLPRI,
                    .revents = 0,
            };

            while (true) {
                int rc = poll(&fodUiPoll, 1, -1);
                if (rc < 0) {
                    LOG(ERROR) << "failed to poll " << FOD_UI_PATH << ", err: " << rc;
                    continue;
                }

                if (fodUiPoll.revents & (POLLERR | POLLPRI)) {
                    bool nitState = readBool(fd.get());
                    mDevice->extCmd(mDevice, COMMAND_NIT,
                                    nitState ? PARAM_NIT_UDFPS : PARAM_NIT_NONE);
                }
            }
        }).detach();
    }

    void onFingerDown(uint32_t /*x*/, uint32_t /*y*/, float /*minor*/, float /*major*/) override {
        if (mAuthSuccess.load()) return;
        // Emit BTN_INFO=1 via synaptics_s3908p before enabling LHBM so libgf_hal
        // enters capture wait before fod_ui=1 triggers COMMAND_NIT.
        set(FOD_FINGER_DOWN_PATH, FOD_FINGER_DOWN);
        set(FOD_HBM_PATH, FOD_HBM_ON);
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_STATUS, PARAM_FOD_PRESSED);
    }

    void onFingerUp() override {
        set(FOD_HBM_PATH, FOD_HBM_OFF);
        set(FOD_FINGER_DOWN_PATH, FOD_FINGER_UP);
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_STATUS, PARAM_FOD_RELEASED);
    }

    void onAcquired(int32_t result, int32_t /*vendorCode*/) override {
        switch (static_cast<AcquiredInfo>(result)) {
            case AcquiredInfo::GOOD:
            case AcquiredInfo::PARTIAL:
            case AcquiredInfo::INSUFFICIENT:
            case AcquiredInfo::SENSOR_DIRTY:
            case AcquiredInfo::TOO_SLOW:
            case AcquiredInfo::TOO_FAST:
            case AcquiredInfo::TOO_DARK:
            case AcquiredInfo::TOO_BRIGHT:
            case AcquiredInfo::IMMOBILE:
            case AcquiredInfo::LIFT_TOO_SOON:
                onFingerUp();
                break;
            default:
                break;
        }
    }

    void onAuthenticationSucceeded() override {
        mAuthSuccess.store(true);
        onFingerUp();
        std::thread([this]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            mAuthSuccess.store(false);
        }).detach();
    }

    void onAuthenticationFailed() override { onFingerUp(); }

    void cancel() override { onFingerUp(); }

  private:
    fingerprint_device_t* mDevice = nullptr;
    std::atomic<bool> mAuthSuccess{false};
};

static UdfpsHandler* create() {
    return new XiaomiMonaUdfpsHandler();
}

static void destroy(UdfpsHandler* handler) {
    delete handler;
}

extern "C" UdfpsHandlerFactory UDFPS_HANDLER_FACTORY = {
        .create = create,
        .destroy = destroy,
};
