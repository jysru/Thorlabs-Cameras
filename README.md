# Thorlabs-Cameras

Control Thorlabs cameras using Matlab and Python.



## Installation

1. Install [Thorcam 64bit](https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=ThorCam)

2. Ensure installation is set to default location: `C:\Program Files\Thorlabs\Scientific Imaging\ThorCam`


### Matlab specific instructions

- Add this `./matlab` to Matlab path


## Python installation

The Python SDK supports Thorlabs scientific-camera series CC215, CS126, CS135, CS165, CS2100, CS235, CS505, and CS895. 

The Python SDK is a wrapper around the native SDK, which means python applications need access to the native camera DLLs.

To finish installing the Python SDK, please follow these directions:

1. Ensure dependencies are installed: `python.exe -m pip install -r ./python/resources/requirements.txt`

2. Install the package: `python.exe -m pip install ./python/resources/thorlabs_tsi_camera_python_sdk_package.zip`


## Usage

For Matlab users, check `./matlab/examples`

For Python users, check `./python/example_camera.ipynb`