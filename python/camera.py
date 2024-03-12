from thorlabs_tsi_sdk.tl_camera import TLCameraSDK
import matplotlib.pyplot as plt
import numpy as np
import time


def _add_sdk_path():
    try:
        # if on Windows, use the provided setup script to add the DLLs folder to the PATH
        from windows_setup import configure_path
        configure_path()
    except ImportError:
        configure_path = None



class ThorlabsCamera:

    def __init__(self, serial_number: str, name: str = '') -> None:
        _add_sdk_path()
        self._load_sdk()
        self.discover()
        self.open(serial_number)
        self.device.name = name

    def _load_sdk(self):
        self.sdk = TLCameraSDK()

    def discover(self):
        self.available_cameras = self.sdk.discover_available_cameras()
        if len(self.available_cameras) < 1:
            raise ValueError("No cameras detected")
        else:
            print(f"Available cameras: {self.available_cameras}")

    def open(self, serial_number: str):
        if serial_number in self.available_cameras:
            self.device = self.sdk.open_camera(serial_number)

    def setup(self,
              exposure_time_us: int = 1000,
              roi_xy_size: tuple[int] = (512, 512),
              roi_xy_upper_left: tuple[int] = (0, 0),
              frames_per_trigger_zero_for_unlimited: int = 0,
              image_poll_timeout_ms: int = 1000,
              ):
        self.device.exposure_time_us = exposure_time_us
        self.device.frames_per_trigger_zero_for_unlimited = frames_per_trigger_zero_for_unlimited
        self.device.image_poll_timeout_ms = image_poll_timeout_ms
        self.device.roi = (
            roi_xy_upper_left[0],
            roi_xy_upper_left[1],
            roi_xy_upper_left[0] + roi_xy_size[0],
            roi_xy_upper_left[1] + roi_xy_size[1],
            )

    def run(self):
        self.device.arm(2)
        self.device.issue_software_trigger()

    def get_snapshot(self, display_timer: bool = False):
        start = time.time()
        frame = self.device.get_pending_frame_or_null()
        if frame is not None:
            self.last_frame = np.copy(frame.image_buffer)
        else:
            raise ValueError("No frame arrived within the timeout!")
        stop = time.time()
        self.last_frame_duration = stop - start
        if display_timer:
            print(f"Acquisition time: {self.last_frame_duration * 1e6} us")

    @property
    def exposure_us(self):
        return self.device.exposure_time_us
    
    @exposure_us.setter
    def exposure_us(self, value: int):
        if value < self.device.exposure_time_range_us.min:
            self.device.exposure_time_us = self.device.exposure_time_range_us.min
        elif value > self.device.exposure_time_range_us.max:
            self.device.exposure_time_us = self.device.exposure_time_range_us.max
        else:
            self.device.exposure_time_us = value

    def show(self,
             figsize: tuple[int] = (6, 6),
             display_colorbar: bool = True,
             display_title: bool = True,
             max: int = None,
             min: int = 0,
             amplitude: bool = False,
             ):
        fig = plt.figure(figsize=figsize)
        plt.imshow(self.last_frame, vmin=min, vmax=max)
        if display_title:
            plt.title(f"{self.device.name} {'amplitude' if amplitude else 'intensity'}")
        if display_colorbar:
            plt.colorbar()

    def live(self):
        pass

    def dispose(self):
        self.__del__()

    def __del__(self):
        self.device.dispose()
        self.sdk.dispose()

    
    
        