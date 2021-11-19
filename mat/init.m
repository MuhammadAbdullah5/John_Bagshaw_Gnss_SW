%================== GNSS SDR ===========================%
%                                                       
% @brief: Software Defined GNSS Receiver Software Model 
% @date: 11-19-2021                                     
%=======================================================%

%% Clean up the environment first =========================================
clear; close all; clc;

format ('compact');
format ('long', 'g');

%--- Include folders with functions ---------------------------------------
addpath include             % The software receiver functions
addpath geoFunctions        % Position calculation related functions

%% Print startup ==========================================================
fprintf(['\n',...
    'Welcome to:  softGNSS\n\n', ...
    'An open source GNSS SDR software project initiated by:\n\n', ...
    '              Danish GPS Center/Aalborg University\n\n', ...
    'The code was improved by GNSS Laboratory/University of Colorado.\n\n',...
    'The software receiver softGNSS comes with ABSOLUTELY NO WARRANTY;\n',...
    'for details please read license details in the file license.txt. This\n',...
    'is free software, and  you  are  welcome  to  redistribute  it under\n',...
    'the terms described in the license.\n\n']);
fprintf('                   -------------------------------\n\n');

%% Initialize constants, settings =========================================
settings = init_settings();

%% Generate plot of raw data and ask if ready to start processing =========
try
    probe_data(settings);
catch
    % There was an error, print it and exit
    errStruct = lasterror;
    disp(errStruct.message);
    disp('  (run setSettings or change settings in "initSettings.m" to reconfigure)')    
    return;
end
    
disp('  Raw IF data plotted ')
disp('  (run setSettings or change settings in "initSettings.m" to reconfigure)')
disp(' ');

% gnssStart = input('Enter "1" to initiate GNSS processing, "2" to run DelayDopplerMap or "0" to exit : ');
gnssStart = 2;

if (gnssStart == 1)
    disp(' ');
    post_processing
elseif (gnssStart == 2)    
    disp(' ');
    ddm_processing
    delay_doppler_map
end

