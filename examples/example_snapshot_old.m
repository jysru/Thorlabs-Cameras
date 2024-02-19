%% Cleanup
clear all
close all

addpath(pwd)

%% Load sdk
sdk = ThorlabsCameraSDKLoader();

%% Create cameras
cam1 = ThorlabsCameraOld("05564", sdk, struct('name', "Near field"));

%% Setup cameras
setup_opts = struct('ExposureTimeUs', 9000, 'ROISize', 512, 'ROIPosition', [0, 0]);
cam1.setup(setup_opts)

%% Arm cameras
cam1.run()

%% Change exposure and get snapshots
cam1.set_exposure(setup_opts.ExposureTimeUs);

for i=1:10
    cam1.get_snapshot(struct('DisplayTimer', false));
    cam1.show(struct('FigureNumber', 1));
    drawnow
    pause(0.1)
end

%% Get last frame data
data = cam1.lastFrame;

%% Disarm and close cameras
delete(cam1)

%% Delete SDK
delete(sdk)
