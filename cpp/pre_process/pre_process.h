#ifndef __PRE_PROCESS__
#define __PRE_PROCESS__

#include "cfg/config_sdr_params.h"

using namespace std;
using namespace config;

namespace processing
{

void PreProcess(
	SdrParams_t&         sdrParams, 
	PreProcessSignals_t* p_prepSignal, 
	int32_t              numAcqAlgos,
	RxDataChannelMem_t*  rxDataPerFrame,
	int32_t              numRxDataChannels
);


}



#endif // __PRE_PROCESS__