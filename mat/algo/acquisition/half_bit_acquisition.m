function acqResults = half_bit_acquisition(longSignal, settings, data_length)

%longSignal = baseband data ;
%settings = settings;

%
%Function performs half bit acquisition on the collected "data". It
%searches for GPS signals of all satellites, which are listed in field
%"acqSatelliteList" in the settings structure. Function saves code phase
%and frequency of the detected signals in the "acqResults" structure.
%
%acqResults = acquisition(longSignal, settings)
%
%   Inputs:
%       longSignal    - 20 ms of raw signal from the front-end 
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

%% Initialization =========================================================

% Find number of samples per spreading code
samplesPerCode = round(settings.samplingFreq / ...
                        (settings.codeFreqBasis / settings.codeLength));

% Create two 10 msec vectors of data to correlate with and one with zero DC

if floor(data_length / samplesPerCode) > 20
    data_len_ms = 10;
    
elseif floor(data_length / samplesPerCode) > 12
    data_len_ms = floor(data_length / samplesPerCode) - 10;
    
else
    error('not sufficient data available for half bit acquisition method');
    
end

signalEven = longSignal(1 : data_len_ms*samplesPerCode);
signalOdd  = longSignal(10*samplesPerCode+1 : (10 + data_len_ms)*samplesPerCode);

% Find sampling period
ts = 1 / settings.samplingFreq;

% Find phase points of the local carrier wave 
phasePoints = (0 : (samplesPerCode-1)) * 2 * pi * ts;

% Number of the frequency bins for the given acquisition band (500Hz steps)
numberOfFrqBins = round(settings.acqSearchBand * 2) + 1;

% Generate all C/A codes and sample them according to the sampling freq.
caCodesTable = makeCaTable(settings);

% Carrier frequencies of the frequency bins
frqBins     = zeros(1, numberOfFrqBins);


%--- Initialize acqResults ------------------------------------------------
% Carrier frequencies of detected signals
acqResults.carrFreq     = zeros(1, 32);
% C/A code phases of detected signals
acqResults.codePhase    = zeros(1, 32);
% Correlation peak ratios of the detected signals
acqResults.peakMetric   = zeros(1, 32);

fprintf('(');

% Perform search for all listed PRN numbers ...
for PRN = settings.acqSatelliteList

    %--- Initialize arrays to speed up the code -------------------------------
    % Search results of all frequency bins and code shifts (for one satellite)
    resultsEven = zeros(numberOfFrqBins, samplesPerCode);
    resultsOdd  = zeros(numberOfFrqBins, samplesPerCode);


%% Correlate signals ======================================================   
    %--- Perform DFT of C/A code ------------------------------------------
    caCodeFreqDom = conj(fft(caCodesTable(PRN, :)));
    
    %--- Make the correlation for whole frequency band (for all freq. bins)
    for frqBinIndex = 1:numberOfFrqBins

        %--- Generate carrier wave frequency grid (0.5kHz step) -----------
        frqBins(frqBinIndex) = settings.IF - ...
                               (settings.acqSearchBand/2) * 1000 + ...
                               0.5e3 * (frqBinIndex - 1);

        %--- Generate local sine and cosine -------------------------------
        sinCarr = sin(frqBins(frqBinIndex) * phasePoints);
        cosCarr = cos(frqBins(frqBinIndex) * phasePoints);

        for ms = 1:data_len_ms
            %--- "Remove carrier" from the signal -----------------------------
            IEven = sinCarr .* signalEven((ms-1)*samplesPerCode+1:ms*samplesPerCode);
            QEven = cosCarr .* signalEven((ms-1)*samplesPerCode+1:ms*samplesPerCode);
            IOdd  = sinCarr .* signalOdd ((ms-1)*samplesPerCode+1:ms*samplesPerCode);
            QOdd  = cosCarr .* signalOdd ((ms-1)*samplesPerCode+1:ms*samplesPerCode);
            
            %--- Convert the baseband signal to frequency domain --------------
            IQfreqDomEven = fft(IEven + 1i*QEven);
            IQfreqDomOdd  = fft(IOdd  + 1i*QOdd);
            
            %--- Multiplication in the frequency domain (correlation in time
            %domain)
            convCodeIQEven = IQfreqDomEven .* caCodeFreqDom;
            convCodeIQOdd  = IQfreqDomOdd  .* caCodeFreqDom;
            
            %--- Perform inverse DFT and store correlation results ------------
            acqResEven = abs(ifft(convCodeIQEven)) .^ 2;
            acqResOdd  = abs(ifft(convCodeIQOdd)) .^ 2;
            
            %
            resultsEven(frqBinIndex, :) = resultsEven(frqBinIndex, :) + acqResEven;
            resultsOdd(frqBinIndex, :)  = resultsOdd (frqBinIndex, :) + acqResOdd;
            
        end

    end % frqBinIndex = 1:numberOfFrqBins
    %% Look for correlation peaks in the results ==============================
    
    %--- Check which msec had the greater power and save that, will
    %"blend" 1st and 2nd msec but will correct data bit issues
    % compare between even and odd sets
    if max(max(resultsEven)) > max(max(resultsOdd))
        results = resultsEven;
        signal0DC  = signalEven - mean(signalEven); 
    else
        results = resultsOdd;
        signal0DC  = signalOdd - mean(signalOdd); 
    end
        
    % Find the highest peak and compare it to the second highest peak
    % The second peak is chosen not closer than 1 chip to the highest peak
    
    %--- Find the correlation peak and the carrier frequency --------------
    [peakSize frequencyBinIndex] = max(max(results, [], 2));

    %--- Find code phase of the same correlation peak ---------------------
    [peakSize codePhase] = max(max(results));

    %--- Find 1 chip wide C/A code phase exclude range around the peak ----
    samplesPerCodeChip   = round(settings.samplingFreq / settings.codeFreqBasis);
    excludeRangeIndex1 = codePhase - samplesPerCodeChip;
    excludeRangeIndex2 = codePhase + samplesPerCodeChip;

    %--- Correct C/A code phase exclude range if the range includes array
    %boundaries
    if excludeRangeIndex1 < 2
        codePhaseRange = excludeRangeIndex2 : ...
                         (samplesPerCode + excludeRangeIndex1);
                         
    elseif excludeRangeIndex2 >= samplesPerCode
        codePhaseRange = (excludeRangeIndex2 - samplesPerCode) : ...
                         excludeRangeIndex1;
    else
        codePhaseRange = [1:excludeRangeIndex1, ...
                          excludeRangeIndex2 : samplesPerCode];
    end

    %--- Find the second highest correlation peak in the same freq. bin ---
    secondPeakSize = max(results(frequencyBinIndex, codePhaseRange));

    %--- Store result -----------------------------------------------------
    acqResults.peakMetric(PRN) = peakSize/secondPeakSize;
    
    % If the result is above threshold, then there is a signal ...
    if (peakSize/secondPeakSize) > settings.acqThreshold

%% Fine resolution frequency search =======================================
        
        %--- Indicate PRN number of the detected signal -------------------
        fprintf('%02d ', PRN);
        
        %--- Generate 10msec long C/A codes sequence for given PRN --------
        caCode = generateCAcode(PRN);
        
        codeValueIndex = floor((ts * (1:(data_len_ms-1)*samplesPerCode)) / ...
                               (1/settings.codeFreqBasis));
                           
        longCaCode = caCode((rem(codeValueIndex, 1023) + 1));
    
        %--- Remove C/A code modulation from the original signal ----------
        % (Using detected C/A code phase)
        xCarrier = ...
            signal0DC(codePhase:(codePhase + (data_len_ms-1)*samplesPerCode-1)) ...
            .* longCaCode;
        
        %--- Find the next highest power of two and increase by 8x --------
        fftNumPts = 8*(2^(nextpow2(length(xCarrier))));
        
        %--- Compute the magnitude of the FFT, find maximum and the
        %associated carrier frequency 
        fftxc = abs(fft(xCarrier, fftNumPts)); 
        
        uniqFftPts = ceil((fftNumPts + 1) / 2);
        [fftMax, fftMaxIndex] = max(fftxc(5 : uniqFftPts-5));
        
        fftFreqBins = (0 : uniqFftPts-1) * settings.samplingFreq/fftNumPts;
        
        %--- Save properties of the detected satellite signal -------------
        acqResults.carrFreq(PRN)  = fftFreqBins(fftMaxIndex);
        acqResults.codePhase(PRN) = codePhase;
    
    else
        %--- No signal with this PRN --------------------------------------
        fprintf('. ');
    end   % if (peakSize/secondPeakSize) > settings.acqThreshold
    
%     figure(1023)
%     subplot(2,1,1)
%     mesh(results)
%     ylabel('Frequency')
%     xlabel('Code phase [chips]')
%     title('Delay Doppler Map')
%     subplot(2,1,2)
%     imagesc(results)
%     colorbar
    
end    % for PRN = satelliteList
%=== Acquisition is over ==================================================
fprintf(')\n');
