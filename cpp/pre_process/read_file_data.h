#ifndef __READ_DATA_FILE__
#define __READ_DATA_FILE__

#include "read_file_data.h"
#include "cfg/config_sdr_params.h"

using namespace std;
using namespace config;

namespace processing
{

	void ReadDataFile(
		SdrParams_t& sdrParams, 
		RxDataChannelMem_t* p_rxDataMem,
		int32_t numRxDataChannels
	);

}

#endif // __READ_DATA_FILE__
