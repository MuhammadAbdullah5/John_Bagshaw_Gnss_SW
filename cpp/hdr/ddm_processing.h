/**
 * @file ddm_processing.h
 *
 * Header file for DDM processing in C++
 *
 * Project Title: GNSS-R SDR
 * Author: John Bagshaw
 * Co-author: Surabhi Guruprasad
 * Contact: jotshaw@yorku.ca
 * Supervisor: Prof. Sunil Bisnath
 * Project Manager: Junchan Lee
 * Institution: Lassonde School of Engineering, York University, Canada.
 **/

#pragma once
#include "result_read_write.hpp"
#include "acquisition.hpp"
#include "gen_code.hpp"
#include "matcreat.hpp"
#include "constants.h"
#include "timing.hpp"
#include "fftw3.h"
#include "mat.h"

#include <thread>
#include <mutex>
#include <string.h>
#include <math.h>

void DelayDopplerMap(const Settings_t* settings);

void DdmProcessing(const Settings_t* settings);

double NTconvert(int unconverted);