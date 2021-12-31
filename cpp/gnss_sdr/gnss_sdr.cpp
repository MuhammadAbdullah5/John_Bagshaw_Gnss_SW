// gnss_sdr.cpp : This file contains the 'main' function. Program execution begins and ends there.
//
#include <iostream>

#include "cfg/config_sdr_params.h"
#include "cfg/logger.h"

#include "pre_process/pre_process.h"
#include "process/process.h"
#include "post_process/post_process.h"

#include "post_process/save_acquisition_results.h"

using namespace std;
using namespace processing;

const std::string swVersionInfo = "GNSS_SDR_V0.1";
static config::SdrParams_t s_sdrParams;

int main()
{
    printString("s", "==================================================================");
    printString("st", "Welcome!MATLAB Reference Software - Defined Radio : ", swVersionInfo);
    printString("s", "==================================================================");

    // Configure SDR parameters
    ConfigSdrParams(&s_sdrParams);


    // Assign memory Pre-process signals

    PreProcessSignals_t *preProcessSigArr = new PreProcessSignals_t [s_sdrParams.sysParams.numAcqAlgos];

    // Process each file.
    while (s_sdrParams.stateParams.numFilesProcessed <
        s_sdrParams.stateParams.numFilesToProcess)
    {

        printString("s", "-----------------------------------------------------------------");
        printString("st", "Data processing started for file: ", s_sdrParams.stateParams.fileNames
            [s_sdrParams.stateParams.numFilesProcessed]);
        printString("s", "-----------------------------------------------------------------");


        DataParams_t        * p_fileDataParams  = &s_sdrParams.dataParamsList [s_sdrParams.stateParams.currFrameNum];
        int32_t               numRxDataChannels = p_fileDataParams->selectedChannel == -1 ?
                                                  p_fileDataParams->totalChannels : 1;
        RxDataChannelMem_t   *p_rxDataChMem      = new RxDataChannelMem_t  [numRxDataChannels];
        ProcessSignals_t     *processResults     = new ProcessSignals_t    [s_sdrParams.sysParams.numAcqAlgos* numRxDataChannels];
        PostProcessResults_t *postProcessResults = new PostProcessResults_t[s_sdrParams.sysParams.numAcqAlgos * numRxDataChannels];


        // Reset parameters
        s_sdrParams.stateParams.currFrameNum = 0;
        for (int32_t algo = 0; algo < s_sdrParams.sysParams.numAcqAlgos; algo++)
        {
            preProcessSigArr[algo].caCodeTableMemType = MEM_INVALID;
            preProcessSigArr[algo].dopplerCplxExpMemType = MEM_INVALID;
            preProcessSigArr[algo].dopplerCplxExpDeltaMemType = MEM_INVALID;
            for (int32_t ch = 0; ch < numRxDataChannels; ch++)
            {
                if (!algo)
                {
                    p_rxDataChMem[ch].rxDataPerFrameMemType = MEM_INVALID;
                }
                processResults[ch * s_sdrParams.sysParams.numAcqAlgos + algo].ddMapMemType = MEM_INVALID;
                postProcessResults[ch * s_sdrParams.sysParams.numAcqAlgos + algo].accumDdmMemType = MEM_INVALID;
                postProcessResults[ch * s_sdrParams.sysParams.numAcqAlgos + algo].numAcqSatellites = 0;
            }
        }


        // pre-processing per input data file.
        PreProcess(
            s_sdrParams, 
            preProcessSigArr, 
            s_sdrParams.sysParams.numAcqAlgos, 
            p_rxDataChMem, 
            numRxDataChannels
        );


        // Data frame processing
        while (s_sdrParams.stateParams.currFrameNum <
            s_sdrParams.stateParams.numTotalFrames)
        {

            // Do the processing
            Process(
                s_sdrParams,
                preProcessSigArr,
                s_sdrParams.sysParams.numAcqAlgos,
                p_rxDataChMem,
                numRxDataChannels,
                processResults
            );


            // Do post processing.
            PostProcess(
                s_sdrParams,
                processResults,
                s_sdrParams.sysParams.numAcqAlgos,
                p_rxDataChMem,
                numRxDataChannels,
                postProcessResults
            );

            // Move to next frame
            s_sdrParams.stateParams.currFrameNum = 
                s_sdrParams.stateParams.currFrameNum + 1;
        }

        // Save results.
        SaveAcqResults(
            s_sdrParams,
            s_sdrParams.sysParams.numAcqAlgos,
            numRxDataChannels,
            postProcessResults
        );

        // Deallocate the memory
        for (int32_t algo = 0; algo < s_sdrParams.sysParams.numAcqAlgos; algo++)
        {
            if (preProcessSigArr[algo].caCodeTableMemType != MEM_INVALID)
            {
                delete[] preProcessSigArr[algo].caCodeTable;
            }
            if (preProcessSigArr[algo].dopplerCplxExpMemType != MEM_INVALID)
            {
                delete[] preProcessSigArr[algo].dopplerCplxExp;
            }
            if (preProcessSigArr[algo].dopplerCplxExpDeltaMemType != MEM_INVALID)
            {
                delete[] preProcessSigArr[algo].dopplerCplxExpDelta;
            }
            for (int32_t ch = 0; ch < numRxDataChannels; ch++)
            {
                if (!algo)
                {
                    if (p_rxDataChMem[ch].rxDataPerFrameMemType == MEM_INVALID)
                    {
                        delete[] p_rxDataChMem[ch].rxDataPerFrame;
                    }
                }
                if (processResults[ch * s_sdrParams.sysParams.numAcqAlgos + algo].ddMapMemType == MEM_INVALID)
                {
                    delete[] processResults[ch * numRxDataChannels + algo].ddMap;
                }
                //if (postProcessResults[ch * numRxDataChannels + algo].accumDdmMemType == MEM_INVALID)
                //{
                //    delete[] postProcessResults[ch * s_sdrParams.sysParams.numAcqAlgos + algo].accumDdm;
                //}
            }
        }

        printString("s", "-----------------------------------------------------------------");
        printString("st", "Data processing completed for file: ", 
            s_sdrParams.stateParams.fileNames
            [s_sdrParams.stateParams.numFilesProcessed]);
        printString("s", "-----------------------------------------------------------------");


        // Next File
        s_sdrParams.stateParams.numFilesProcessed = 
            s_sdrParams.stateParams.numFilesProcessed + 1;

    }

    printString("s", "============================");
    printString("s", "Program Completed. Good Bye!");
    printString("s", "============================");
}
