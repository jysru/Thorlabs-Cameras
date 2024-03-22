import matplotlib.pyplot as plt
import numpy as np
import time
import os

import typing
import threading

from PIL import Image, ImageTk

from thorlabs_tsi_sdk.tl_camera import TLCameraSDK, TLCamera, Frame
from thorlabs_tsi_sdk.tl_camera_enums import SENSOR_TYPE
from thorlabs_tsi_sdk.tl_mono_to_color_processor import MonoToColorProcessorSDK

try:
    #  For python 2.7 tkinter is named Tkinter
    import TKinter as tk
except ImportError:
    import tkinter as tk

try:
    #  For Python 2.7 queue is named Queue
    import Queue as queue
except ImportError:
    import queue



def _add_sdk_path():
    try:
        # if on Windows, use the provided setup script to add the DLLs folder to the PATH
        from windows_setup import configure_path
        configure_path()
    except ImportError:
        configure_path = None



class ThorlabsCamera:
    _ABSPATH_TO_DLLS = 'C:/Drivers/Scientific_Camera_Interfaces_Windows-2.1/SDK/Python Toolkit/dlls/64_lib'
    _MAX_FRAME_ATTEMPTS = 100

    def __init__(self, serial_number: str, name: str = '') -> None:
        self._add_sdk()
        self._load_sdk()
        self.discover()
        self.open(serial_number)
        self.device.name = name

    def _add_sdk(self):
        os.add_dll_directory(self._ABSPATH_TO_DLLS)
        os.environ['PATH'] = self._ABSPATH_TO_DLLS + os.pathsep + os.environ['PATH']

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

    def get_snapshot(self, display_timer: bool = False, max_get_frame: int = _MAX_FRAME_ATTEMPTS):
        start = time.time()
        frame = self.device.get_pending_frame_or_null()

        attempt = 0
        while frame is None:
            frame = self.device.get_pending_frame_or_null()
            attempt += 1
            if attempt > max_get_frame:
                print("Could not get a snapshot")
                break
            
        if frame is not None:
            self.last_frame = np.copy(frame.image_buffer).astype(np.uint16)
        else:
            self.last_frame = None
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
        print("Generating app...")
        root = tk.Tk()
        root.title(self.device.name)
        image_acquisition_thread = ImageAcquisitionThread(self.device)
        camera_widget = LiveViewCanvas(parent=root, image_queue=image_acquisition_thread.get_output_queue())

        print("Starting image acquisition thread...")
        image_acquisition_thread.start()

        print("App starting")
        root.mainloop()

        print("Waiting for image acquisition thread to finish...")
        image_acquisition_thread.stop()
        image_acquisition_thread.join()

    def dispose(self):
        self.__del__()

    def __del__(self):
        self.device.dispose()
        self.sdk.dispose()

    


""" LiveViewCanvas

This is a Tkinter Canvas object that can be reused in custom programs. The Canvas expects a parent Tkinter object and 
an image queue. The image queue is a queue.Queue that it will pull images from, and is expected to hold PIL Image 
objects that will be displayed to the canvas. It automatically adjusts its size based on the incoming image dimensions.

"""

class LiveViewCanvas(tk.Canvas):

    def __init__(self, parent, image_queue):
        # type: (typing.Any, queue.Queue) -> LiveViewCanvas
        self.image_queue = image_queue
        self._image_width = 0
        self._image_height = 0
        tk.Canvas.__init__(self, parent)
        self.pack()
        self._get_image()

    def _get_image(self):
        try:
            image = self.image_queue.get_nowait()
            self._image = ImageTk.PhotoImage(master=self, image=image)
            if (self._image.width() != self._image_width) or (self._image.height() != self._image_height):
                # resize the canvas to match the new image size
                self._image_width = self._image.width()
                self._image_height = self._image.height()
                self.config(width=self._image_width, height=self._image_height)
            self.create_image(0, 0, image=self._image, anchor='nw')
        except queue.Empty:
            pass
        self.after(10, self._get_image)



""" ImageAcquisitionThread

This class derives from threading.Thread and is given a TLCamera instance during initialization. When started, the 
thread continuously acquires frames from the camera and converts them to PIL Image objects. These are placed in a 
queue.Queue object that can be retrieved using get_output_queue(). The thread doesn't do any arming or triggering, 
so users will still need to setup and control the camera from a different thread. Be sure to call stop() when it is 
time for the thread to stop.

"""


class ImageAcquisitionThread(threading.Thread):

    def __init__(self, camera):
        # type: (TLCamera) -> ImageAcquisitionThread
        super(ImageAcquisitionThread, self).__init__()
        self._camera = camera
        self._previous_timestamp = 0

        # setup color processing if necessary
        # if self._camera.camera_sensor_type != SENSOR_TYPE.BAYER:
            # Sensor type is not compatible with the color processing library
        self._is_color = False
        # else:
        #     self._mono_to_color_sdk = MonoToColorProcessorSDK()
        self._image_width = self._camera.image_width_pixels
        self._image_height = self._camera.image_height_pixels

        self._bit_depth = camera.bit_depth
        self._camera.image_poll_timeout_ms = 0  # Do not want to block for long periods of time
        self._image_queue = queue.Queue(maxsize=2)
        self._stop_event = threading.Event()

    def get_output_queue(self):
        # type: (type(None)) -> queue.Queue
        return self._image_queue

    def stop(self):
        self._stop_event.set()

    def _get_image(self, frame):
        # type: (Frame) -> Image
        # no coloring, just scale down image to 8 bpp and place into PIL Image object
        scaled_image = frame.image_buffer >> (self._bit_depth - 8)
        return Image.fromarray(scaled_image)

    def run(self):
        while not self._stop_event.is_set():
            try:
                frame = self._camera.get_pending_frame_or_null()
                if frame is not None:
                    pil_image = self._get_image(frame)
                    self._image_queue.put_nowait(pil_image)
            except queue.Full:
                # No point in keeping this image around when the queue is full, let's skip to the next one
                pass
            except Exception as error:
                print("Encountered error: {error}, image acquisition will stop.".format(error=error))
                break
        print("Image acquisition has stopped")
