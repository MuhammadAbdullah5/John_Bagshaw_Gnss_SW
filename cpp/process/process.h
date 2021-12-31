#ifndef __PROCESS__
#define __PROCESS__

#include "cfg/config_sdr_params.h"

using namespace std;
using namespace config;

namespace processing
{

	void Process(
		SdrParams_t& sdrParams,
		PreProcessSignals_t* p_prepSignal,
		int32_t              numAcqAlgos,
		RxDataChannelMem_t* rxDataPerFrame,
		int32_t              numRxDataChannels,
		ProcessSignals_t* procesSignals
	);


}



#endif // __PRE_PROCESS__
