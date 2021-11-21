function acqResults = weak_acquisition(longSignal, settings)

%longSignal = data;
%settings = settings;

%
%Function performs cold start acquisition on the collected "data". It
%searches for GPS signals of all satellites, which are listed in field
%"acqSatelliteList" in the settings structure. Function saves code phase
%and frequency of the detected signals in the "acqResults" structure.
%
%acqResults = acquisition(longSignal, settings)
%
%   Inputs:
%       longSignal    - 11 ms of raw signal from the front-end 
%       settings      - Receiver settings. Provides information about
%                       sampling and intermediate frequencies and other
%                       parameters including the list of the satellites to
%                       be acquired.
%   Outputs:
%       acqResults    - Function saves code phases and frequencies of the 
%                       detected signals in the "acqResults" structure. The
%                       field "carrFreq" is set to 0 if the signal is not
%                       detected for the given PRN number. 
 
%--------------------------------------------------------------------------
%                           SoftGNSS v3.0
% 
% Copyright (C) Darius Plausinaitis and Dennis M. Akos
% Written by Darius Plausinaitis and Dennis M. Akos
% Based on Peter Rinder and Nicolaj Bertelsen
%--------------------------------------------------------------------------
%This program is free software; you can redistribute it and/or
%modify it under the terms of the GNU General Public License
%as published by the Free Software Foundation; either version 2
%of the License, or (at your option) any later version.
%
%This program is distributed in the hope that it will be useful,
%but WITHOUT ANY WARRANTY; without even the implied warranty of
%MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%GNU General Public License for more details.
%
%You should have received a copy of the GNU General Public License
%along with this program; if not, write to the Free Software
%Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
%USA.
%--------------------------------------------------------------------------

%CVS record:
%$Id: acquisition.m,v 1.1.2.12 2006/08/14 12:08:03 dpl Exp $

%% Initialization =========================================================

% Find number of samples per spreading code
samplesPerCode = settings.samplesPerCode;

% Create two 1msec vectors of data to correlate with and one with zero DC
signal0DC = longSignal - mean(longSignal); 

% Find sampling period
ts = 1 / settings.samplingFreq;

% Find phase points of the local carrier wave 
phasePoints = (0 : (samplesPerCode-1)) * 2 * pi * ts;

% Number of the frequency bins for the given acquisition band (500Hz steps)
numberOfFrqBins = round(settings.acqSearchBand * 2) + 1;

% Generate all C/A codes and sample them according to the sampling freq.
caCodesTable = make_ca_table(settings);

%--- Initialize acqResults ------------------------------------------------
% Carrier frequencies of detected signals
acqResults.carrFreq     = zeros(1, 32);
% C/A code phases of detected signals
acqResults.codePhase    = zeros(1, 32);
% Correlation peak ratios of the detected signals
acqResults.peakMetric   = zeros(1, 32);

fprintf('(');

Nfd        = settings.acqSearchBand / 0.5 + 1;
Sblock     = floor((samplesPerCode * settings.coherentIntegrationMs) / Nfd);
Nint       = Sblock * Nfd;
Nblocks    = floor(settings.dataExtractLen / Sblock) - Nfd;

% Perform search for all listed PRN numbers ...
for PRN = settings.acqSatelliteList

    signalFound = 0;
    block = 0;
    blockStart = 1;

    while block < Nblocks

        % 1. Convert signal to baseband
        
        % 2. Define block length and rearrange the signal into the matrix
        signal1   = longSignal(blockStart:blockStart+Nint-1);
        signal2   = longSignal(blockStart+Sblock:blockStart+Nint+Sblock-1);
        signal    = signal1 + signal2;
        sigMatrix = reshape(signal, Sblock, Nfd).';

        % 3. Define local PN code and rearrange it also into the matrix
        caCodeMatrix = repmat(caCodesTable(PRN, :), 1, ceil(Nint/samplesPerCode));
        caCodeMatrix = caCodeMatrix(1:Nint);
        caCodeMatrix = reshape(caCodeMatrix, Sblock, Nfd)';
                
        % 4. Do the circular correlation for each of the row
        corrMatrix = zeros(Nfd, Sblock);
        for row = 1:Nfd
            corrMatrix(row, :) = ifft(fft(sigMatrix(row, :)) .* conj(fft(caCodeMatrix(row, :))));
        end
        
        % 5. Do the DFT for each column and check if not greater than threshold
        corrMatrix = abs(fft(corrMatrix)).^2;
        
        % 6. If not, move one block onto next data and start again
        [~, freqBin] = max(max(corrMatrix, [], 2)); 
        [maxFftAbs, codePhase] = max(max(corrMatrix));
        
        samplesPerCodeChip = round(settings.samplingFreq / settings.codeFreqBasis);
        excludeRangeIndex1 = codePhase - samplesPerCodeChip;
        excludeRangeIndex2 = codePhase + samplesPerCodeChip;
        codePhaseRange     = [1:excludeRangeIndex1, excludeRangeIndex2 : Sblock];
        secondMaxFftAbs    = max(corrMatrix(freqBin, codePhaseRange));
        
        peakTo2ndPeakRatio         = maxFftAbs/secondMaxFftAbs;
        acqResults.peakMetric(PRN) = peakTo2ndPeakRatio;
        
        % If the result is above threshold, then there is a signal ...
        if peakTo2ndPeakRatio > settings.acqThreshold
            
            % Save properties of the detected satellite signal
            acqResults.carrFreq(PRN)  = settings.IF + 1 / (settings.coherentIntegrationMs * 1e-3 * freqBin);
            acqResults.codePhase(PRN) = codePhase;
            
            signalFound=1;
            break;
        end
                
        block = block + 1;
        blockStart = blockStart + Sblock;
    end % for next block in the matrix
    
    if signalFound == 1
        fprintf('%d ', PRN);
    else
        fprintf('. ');
    end
    
end    % for PRN = satelliteList
%=== Acquisition is over ==================================================
fprintf(')\n');
